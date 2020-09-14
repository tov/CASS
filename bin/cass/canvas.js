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

class CanvasApi extends RestClient {
  constructor(cass = new (require('../cass'))) {
    super()
    this._cass   = cass
    this._secret = cass.loadSecret('canvas_oauth')
    this._config = cass.loadConfig('canvas')
  }

  async* getUsers(params) {
    const uri = usersUri(await this._config, params)
    for await (const response of this.fetchAll(uri)) {
      for (const user of await response.json()) {
        yield user
      }
    }
  }

  async getModules() {
    const uri = modulesUri(await this._config)

    let result = []
    for await (const response of this.fetchAll(uri)) {
      result.push(...await response.json())
    }

    return result
  }

  async createModule(name, opts = {}) {
    const uri = modulesUri(await this._config)
    const module = {...opts, name}
    return this.fetch(uri, {method: 'POST', body: {module}})
  }

  async deleteModule(id) {
    const uri = modulesUri(await this._config, id)
    return this.fetch(uri, {method: 'DELETE'})
  }
}

module.exports = CanvasApi
