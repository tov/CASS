const RestClient = require('./rest-client')
const {buildUri} = RestClient

const baseUri = (C, path, query) =>
  buildUri(`https://${C.host}/api/v1`, path, query)

const courseUri = (C, path, query) =>
  baseUri(C, buildUri(`courses/${C.course_id}`, path), query)

const usersUri = (C, {enrollment_type = 'student'} = {}) =>
  courseUri(C, 'users', {enrollment_type})

const modulesUri = (C, id) =>
  courseUri(C, buildUri('modules', id))

const moduleItemsUri = (C, id) =>
  courseUri(C, `modules/${id}/items`)

class CanvasApi extends RestClient {
  constructor(cass = new (require('../cass')), {
    dry_run = false,
    verbose = false,
  } = {}) {
    super({dry_run})
    this._cass   = cass
    this._secret = cass.loadSecret('canvas_oauth')
    this._config = cass.loadConfig('canvas')
    this.dry_run = dry_run
    this.verbose = verbose
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

  async createModule(name, opts = {}) {
    this._log({createModule: name})
    const uri = modulesUri(this._config)
    const module = {...opts, name}
    return this.POST(uri, {module})
  }

  async publishModule(id, published = true) {
    this._log({publishModule: id})
    const uri = modulesUri(this._config, id)
    const module = {published}
    return this.PUT(uri, {module})
  }

  async deleteModule(id) {
    this._log({deleteModule: id})
    const uri = modulesUri(this._config, id)
    return this.DELETE(uri)
  }

  async createModuleItem(id, module_item) {
    this._log({createModuleItem: module_item})
    const uri = moduleItemsUri(this._config, id)
    return this.POST(uri, {module_item})
  }

  _log(...args) {
    if (this.verbose) console.log(...args)
  }
}

module.exports = CanvasApi
