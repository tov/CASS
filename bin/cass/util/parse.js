const {alphabet}  = require('./fmt')

const currentYear = new Date().getFullYear()

const dueDate = contents => {
  const match = contents.match(/^(\d\d?)\/(\d\d?)$/)
  if (!match) throw {
    description: 'Could not parse module due date',
    value: contents
  }

  return new Date(currentYear, match[1] - 1, match[2])
}

const slug = raw => {
  const match = raw.match(/^[a-z]+(\d\d)([a-z])-(\d+)$/)
  if (!match) throw {description: 'Could not parse slug', slug}

  const day     = parseInt(match[1])
  const section = 1 + alphabet.indexOf(match[2])
  const item    = parseInt(match[3])

  return {day, section, item}
}

module.exports = {dueDate, slug}
