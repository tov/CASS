const debug = require('debug')('exercises')
const fs   = require('fs')
const path = require('path')

const loadExercises = (table, current) => {
  const match = current.match(/\/([a-zA-Z0-9_-]+)\.md$/)
  if (match) {
    const slug = match[1]
    table[slug] = {slug, filename: current}
  } else try {
    for (const entry of fs.readdirSync(current)) {
      loadExercises(table, path.join(current, entry))
    }
  } catch (_) { }
}

class Exercises {
  constructor(cass = new (require('../cass'))) {
    const dir = cass.root('..', 'ipd', 'web', 'exercises')
    loadExercises(this._contents, dir)
  }

  _contents = {}

  find(slug) {
    return this._contents[slug]
  }
}

module.exports = Exercises
