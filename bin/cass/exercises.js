const debug = require('debug')('exercises')
const fs   = require('fs')
const path = require('path')

const softReaddirSync = (dir) => {
  try {
    return fs.readdirSync(dir)
  } catch (_) {
    return []
  }
}

const loadExercises = (table, base, rel = '') => {
  const abs = path.join(base, rel)
  const match = abs.match(/\/([a-zA-Z0-9_-]+)\.md$/)
  if (match) {
    const slug = match[1]
    table[slug] = {slug, filename: abs}
    debug({slug, path: rel})
    return
  }

  for (const entry of softReaddirSync(abs))
    loadExercises(table, base, path.join(rel, entry))
}

class Exercises {
  constructor(cass) {
    this._base     = cass.root('web', 'exercises')
    this._contents = {}
    this._default  = 'default'
    loadExercises(this._contents, this._base)
  }


  find(slug, use_default = true) {
    return this._contents[slug] ||
      (use_default && this._contents[this._default])
  }
}

module.exports = Exercises
