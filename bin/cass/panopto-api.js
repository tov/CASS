const {buildUri} = require('./rest-client')

class PanoptoApi {
  constructor(cass = new (require('../cass'))) {
    this._cass   = cass
    this._config = cass.loadConfig('panopto')
  }

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
}

module.exports = PanoptoApi
