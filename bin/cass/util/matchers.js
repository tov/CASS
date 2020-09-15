const {argv} = require('process')

class MatchAny {
  constructor(rawPatterns) {
    this._regexps = rawPatterns.map(pat => new RegExp(pat))
  }

  test(subject) {
    return this._regexps.some(re => re.test(subject))
  }
}

module.exports = {MatchAny}
