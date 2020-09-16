const debug         = require('debug')('canvas')

const {wikifyTitle} = require('./util/fmt')
const RestClient    = require('./rest-client')
const {buildUri}    = RestClient

const baseUri = (C, path, query) =>
  buildUri(`https://${C.host}/api/v1`, path, query)

const courseUri = (C, path, query) =>
  baseUri(C, buildUri(`courses/${C.course_id}`, path), query)

const usersUri = (C, {enrollment_type = 'student'} = {}) =>
  courseUri(C, 'users', {enrollment_type})

const pagesUri = (C, path, query) =>
  courseUri(C, buildUri('pages', path, query))

const modulesUri = (C, id) =>
  courseUri(C, buildUri('modules', id))

const moduleItemsUri = (C, id) =>
  courseUri(C, `modules/${id}/items`)

class CanvasApi extends RestClient {
  constructor(cass = new (require('../cass')), {
    dry_run = false,
  } = {}) {
    super({dry_run})
    this._cass   = cass
    this._secret = cass.loadSecret('canvas_oauth')
    this._config = cass.loadConfig('canvas')
    this.dry_run = dry_run
  }

  getCourseId() {
    return this._config.course_id
  }

  getHost() {
    return this._config.host
  }

  getCourseWebBase () {
    return `https://${this.getHost()}/courses/${this.getCourseId()}`
  }

  async* getUsers(params) {
    const uri = usersUri(this._config, params)
    for await (const response of this.fetchAll(uri)) {
      for (const user of await response.json()) {
        yield user
      }
    }
  }

  async getModules() {
    const uri = modulesUri(this._config)

    let result = []
    for await (const response of this.fetchAll(uri)) {
      result.push(...await response.json())
    }

    return result
  }

  async createModule(name, opts = {}, info) {
    debug('createModule(%o)', {name, ...opts, ...info})
    const uri = modulesUri(this._config)
    const module = {...opts, name}
    return this.POST(uri, {module})
  }

  async publishModule(id, published = true, info) {
    debug('publishModule(%o)', {id, published, ...info})
    const uri = modulesUri(this._config, id)
    const module = {published}
    return this.PUT(uri, {module})
  }

  async deleteModule(id, info) {
    debug('deleteModule(%o)', {id, ...info})
    const uri = modulesUri(this._config, id)
    return this.DELETE(uri)
  }

  async createModuleItem(id, module_item, info) {
    debug('createModuleItem(%o)', {id, ...module_item, ...info})
    const uri = moduleItemsUri(this._config, id)
    return this.POST(uri, {module_item})
  }

  async putPage(wiki_page, info) {
    const {body, ...rest} = wiki_page
    debug('createPage(%o)', {...rest, ...info})

    const page_uri = wikifyTitle(wiki_page.title)
    const uri = pagesUri(this._config, page_uri)
    return this.PUT(uri, {wiki_page})
  }
}

module.exports = CanvasApi
