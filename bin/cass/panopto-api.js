const fs = require('fs')
const debug = require('debug')('panopto-api')

const {buildUri} = require('./rest-client')
const parse      = require('./util/parse')

class PanoptoSession {
  constructor(id, slug, title, api) {
    this.id    = id
    this.slug  = slug
    this.title = title
    this._api  = api
  }

  embed(opts) {
    return this._api.embedUrl(this.id, opts)
  }

  static parse(line, api) {
    if (/^\s*(?=#|$)/.test(line)) return

    const match = line.match(/^(\S+)\s+(\S+)\s+\((.*?)\s*\)\s*$/)
    if (!match) throw {
      description: 'Panopto session desciptor parse error',
      data: line
    }

    return new PanoptoSession(match[1], match[2], match[3], api)
  }
}

class PanoptoApi {
  constructor(cass = new (require('../cass'))) {
    this._cass     = cass
    this._config   = cass.loadConfig('panopto')
    this._loadSessions()
  }

  bySlug  = {}
  byDay   = []

  static Session = PanoptoSession

  static embedBase(config) {
    return `https://${config.host}/Panopto/Pages/Embed.aspx`
  }

  embedUrl(id, {
    autoplay      = false,
    offerviewer   = true,
    showtitle     = false,
    showbrand     = false,
    interactivity = 'all',
  } = {}) {
    const config = this._config
    const base   = PanoptoApi.embedBase(config)
    return buildUri(base, null, {
      id, autoplay, offerviewer, showtitle, showbrand, interactivity
    })
  }

  findBySlug(slug, required = false) {
    const attempt = this.bySlug[slug]
    if (required && !attempt) throw {
      description: 'Requested Panopto session not found',
      slug
    }

    return attempt
  }

  findByParts(day, section, item) {
    return this.byDay.getdef(day).getdef(section)[item]
  }

  _storeSession(session) {
    const {day, section, item} = parse.slug(session.slug)
    this.bySlug[session.slug] = session
    this.byDay.setdef(day).setdef(section)[item] = session
  }

  _loadSessions() {
    const filename = this._cass.cache('panopto', 'sessions')
    const content  = fs.readFileSync(filename, 'utf8')
    const sessions = this._sessions

    for (const line of content.split(/\n/)) {
      const session = PanoptoSession.parse(line, this)
      if (session) this._storeSession(session)
    }
  }
}

module.exports = PanoptoApi
