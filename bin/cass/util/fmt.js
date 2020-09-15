
const shortDateOpts = {weekday: 'short', month: 'short', day: 'numeric'}

const shortDate = date =>
  date.toLocaleString('en-US', shortDateOpts)

const day = num =>
  num.toString().padStart(2, '0')

const alphabet = 'abcdefghijklmnopqrstuvwxyz'

const section = index => {
  return alphabet[index - 1]
}

const joinTitle = items =>
  items.map(item => item.title).join('; ')

const buildTitle = (title, items) =>
  title
    ? title
    : joinTitle(items)

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
  buildTitle,
  day,
  joinTitle,
  maybeFormat,
  moduleHead,
  section,
  shortDate,
  slug,
}
