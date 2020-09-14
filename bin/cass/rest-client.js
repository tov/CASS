const fetch       = require('node-fetch')
const fs          = require('fs/promises')
const encode      = require('form-urlencoded').default

const buildUri = (base, path, query) => {
  let result = base
  if (path) result = `${result}/${path}`
  if (query) result = `${result}?${encode(query)}`
  return result
}

class RestClient {
  async fetch(uri, opts = {}) {
    const method  = opts.method || 'GET'
    const headers = {
      Authorization: `Bearer ${await this._secret}`
    }

    const response = await fetch(uri, {
      method,
      headers,
      redirect: 'follow',
      referrerPolicy: 'no-referrer',
    })

    if (!response.ok) {
      const status = `${response.status} ${response.statusText}`
      throw `Could not fetch <${uri}>;\n  reason: ${status}`
    }

    return response
  }

  async fetchNext(response, opts = {}) {
    const link = response.headers.get('Link')
    if (!link) return

    const matches = link.match(/<([^>]*)>; *rel="next"/)
    if (!matches) return

    return this.fetch(matches[1], opts)
  }

  async* fetchAll(uri, opts = {}) {
    for (let response = await this.fetch(uri, opts);
         response;
         response = await this.fetchNext(response, opts)) {
      yield response
    }
  }

  static buildUri = buildUri
}

module.exports = RestClient
