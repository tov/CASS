// formatting utilities

const shortDateOpts = {weekday: 'short', month: 'short', day: 'numeric'}

const shortDate = date =>
  date.toLocaleString('en-US', shortDateOpts)

const day = num =>
  num.toString().padStart(2, '0')

const digits   = '0123456789'
const alphabet = 'abcdefghijklmnopqrstuvwxyz'

const section = index => {
  return alphabet[index - 1]
}

const joinWith = (sep, ...items) =>
  items.filter(x => x).join(sep)

const maybeFormat = (x, k) => x ? k(x) : ''

const moduleHead = (dayNumber, dueDate, maybeTitle) => {
    const paddedDay = day(dayNumber)
    const date      = shortDate(dueDate)
    const title     = maybeFormat(maybeTitle, s => ` (${s})`)
    return `Day ${paddedDay}: ${date}${title}`
}

const slug = (tag, dayNum, secNum, itemNum) => {
  return `${tag}${day(dayNum)}${section(secNum)}-${itemNum}`
}

module.exports = {
  alphabet,
  day,
  digits,
  joinWith,
  maybeFormat,
  moduleHead,
  section,
  shortDate,
  slug,
}
