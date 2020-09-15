const path = require('path')

const pluralize = (count, singular, plural = `${singular}s`) =>
  count == 1 ? singular : plural

const counted = (count, singular, plural) =>
  `${count} ${pluralize(count, singular, plural)}`

exports.getArgs = ({min = 0, usage} = {}) => {
  const {argv: [_, scriptPath, ...args]} = require('process')
  const arg0 = path.basename(scriptPath)

  if (/^-v|--verbose$/.test(args)) {
    require('debug').enable('*')
    args.shift()
  }

  if (args.length < min) {
    throw usage
      ? `Usage: ${arg0} ${usage}`
      : `Error: ${arg0} requires at least ${counted(min, 'argument')}`
  }

  return args
}
