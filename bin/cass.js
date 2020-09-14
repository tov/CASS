const fs         = require('fs')
const {readFile} = require('fs/promises')
const path       = require('path')
const process    = require('process')

const isCourseRoot = dir =>
  fs.existsSync(path.join(dir, '.root'))

const findCourseRoot = start => {
  let dir = start

  do {
    if (isCourseRoot(dir)) {
      return dir
    }

    dir = path.dirname(dir)
  } while (dir !== '/')

  throw `Couldn’t find course root from ${start}`
}

const firstExists = (...args) => {
  for (const arg of args) {
    if (fs.existsSync(arg)) {
      return arg
    }
  }
}

const rtrim = str => str.replace(/\s*$/, '')

const configLine = /(?:^|\n)\s*(?:#[^\n]*)?(?:([_a-zA-Z]\w*)=([^\n]*))?([^\n]+)?(?=\n|$)/g

const parseConfig = (str, filename = '<unknown>') => {
  const result = {}
  let count    = 0

  for (const match of str.matchAll(configLine)) {
    ++count;

    if (match[3]) {
      throw {
        description: 'Syntax error while parsing config',
        filename,
        line: count,
        badInput: match[0],
      }
    }

    if (match[1]) {
      result[match[1]] = match[2]
    }
  }

  return result
}

class Cass {
  constructor() {
    const {path: start} = process.mainModule || {path: process.cwd()}
    this._root = findCourseRoot(start)
    this._base = firstExists(path.join(this._root, 'private'), this._root)
  }

  root(...rest) {
    return path.join(this._root, ...rest)
  }

  base(...rest) {
    return path.join(this._base, ...rest)
  }

  bin(...rest) {
    return this.base('bin', ...rest)
  }

  etc(...rest) {
    return this.base('etc', ...rest)
  }

  lib(...rest) {
    return this.base('lib', ...rest)
  }

  var(...rest) {
    return this.base('var', ...rest)
  }

  db(...rest) {
    return this.base('var', 'db', ...rest)
  }

  cache(...rest) {
    return this.base('var', 'cache', ...rest)
  }

  async loadEtc(...path) {
    return readFile(this.etc(...path), 'utf8')
  }

  async loadSecret(name) {
    return rtrim(await this.loadEtc(`${name}.secret`))
  }

  async loadConfig(name) {
    const filename = `${name}.config`
    return parseConfig(await this.loadEtc(filename), filename)
  }
}

module.exports = Cass