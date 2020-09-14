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
    const realOpts = {
      method: opts.method || 'GET',
      headers: {
        Authorization: `Bearer ${await this._secret}`
      },
      redirect: 'follow',
      referrerPolicy: 'no-referrer',
    }

    if (opts.body) {
      realOpts.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      realOpts.body = encode(opts.body)
    }

    const response = await fetch(uri, realOpts)
    if (!response.ok) throw {
      description: 'Could not fetch URI',
      uri,
      response,
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

  async GET(uri, opts = {}) {
    return this.fetch(uri, {...opts, method: 'GET'})
  }

  async PUT(uri, body, opts = {}) {
    return this.fetch(uri, {...opts, body, method: 'PUT'})
  }

  async POST(uri, body, opts = {}) {
    return this.fetch(uri, {...opts, body, method: 'POST'})
  }

  async DELETE(uri, opts = {}) {
    return this.fetch(uri, {...opts, method: 'DELETE'})
  }

  static buildUri = buildUri
}

module.exports = RestClient
