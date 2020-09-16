
const shortDateOpts = {weekday: 'short', month: 'short', day: 'numeric'}

const shortDate = date =>
  date.toLocaleString('en-US', shortDateOpts)

const day = num =>
  num.toString().padStart(2, '0')

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

const wikifyTitle = title =>
  title.replace(/[?'"]/g, '')
       .replace(/&/g,   ' and ')
       .replace(/@/g,   ' at ')
       .replace(/[.]/g, ' dot ')
       .replace(/#/g,   ' number ')
       .replace(/%/g,   ' percent ')
       .replace(/[/]/g, ' slash ')
       .replace(/[^\w`=+$|><~]/g, '-')
       .replace(/--+/g, '-')
       .replace(/^-/g, '')
       .replace(/-$/g, '')
       .toLowerCase()

module.exports = {
  alphabet,
  day,
  joinWith,
  maybeFormat,
  moduleHead,
  section,
  shortDate,
  slug,
  wikifyTitle,
}
