const debug  = require('debug')('matchers')
const {argv} = require('process')

class MatchAny {
  constructor(rawPatterns) {
    debug({MatchAny: rawPatterns})
    this._regexps = rawPatterns.map(pat => new RegExp(pat))
  }

  test(subject) {
    if (this._regexps.length == 0)
      return true

    for (const regexp of this._regexps)
      if (regexp.test(subject))
        return true

    return false
  }
}

class MatchAnyArg extends MatchAny {
  constructor() {
    super(argv.slice(2))
  }
}

module.exports = {MatchAny, MatchAnyArg}
