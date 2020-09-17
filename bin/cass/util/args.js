const path  = require('path')

class Args {
  _yargs = require('yargs')

  constructor(scriptName, params, descr) {
    this._do(y => y
      .strict()
      .scriptName(scriptName)
      .help()
      .alias('h', 'help')
      .version(false))

    if (params)
      this._do(y => y.usage(`$0 ${params}`, descr, () => {}))
  }

  get argv() {
    const argv = this._yargs.argv
    if (argv.debug) require('debug').enable('*')
    return argv
  }

  _option(name, opts) {
    return this._do(y => y.option(name, opts))
  }

  _do(...fns) {
    for (const fn of fns) {
      this._yargs = fn(this._yargs)
    }

    return this
  }

  static _register(obj) {
    for (const key in obj) {
      this._register1(key, obj[key])
    }
  }

  static _register1(method, {name, alias, ...opts}) {
    this.prototype[method] = function() {
      if (!name) name = method
      if (!alias) alias = name[0]
      return this._option(name, {alias, ...opts})
    }
  }
}

Args._register({
  json: {
    boolean: true,
    description: 'Produce JSON output',
  },

  debug: {
    alias: 'D',
    boolean: true,
    description: 'Print debugging output',
  },

  verbose: {
    boolean: true,
    description: 'Produce more output',
  },

  quiet: {
    boolean: true,
    description: 'Produce less output',
  },

  force: {
    boolean: true,
    description: 'Do it anyway',
  },

  dry_run: {
    alias: 'N',
    boolean: true,
    description: "Don't actually change anything",
  },
})

module.exports = Args
