const {argv} = require('process')

class MatchAny {
  constructor(rawPatterns, flags = '') {
    this._regexps = rawPatterns.map(pat => new RegExp(pat, flags))
  }

  test(subject) {
    return this._regexps.some(re => re.test(subject))
  }
}

module.exports = {MatchAny}
