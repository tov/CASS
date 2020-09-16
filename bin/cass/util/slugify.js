// slugify a title

const {alphabet, digits} = require('./fmt')

const UP = s => s.toUpperCase()


// These are kept as is:
const retainChars = `-_\`=+$|><~${alphabet}${digits}`


// These are going to be mapped pairwise...
const greekI   = 'αβγδεζηικλμνξοπρσςτυω'
const greekO   = 'abgdezeiklmnxoprsstuo'

const accentI1 = 'àáâäãåāăąçćčđďèéêëēėęěğǵḧîïíīįìłḿñńǹň'
const accentO1 = 'aaaaaaaaacccddeeeeeeeegghiiiiiilmnnnn'

const accentI2 = 'ôöòóøōõőṕŕřśšşșťțûüùúūǘůűųẃẍÿýžźż'
const accentO2 = 'ooooooooprrssssttuuuuuuuuuwxyyzzz'

const accentI  = accentI1 + accentI2 + UP(accentI1) + UP(accentI2)
const accentO  = accentO1 + accentO2 +    accentO1 +     accentO2

const puncI    = ' ,:;'
const puncO    = '----'

const ALPHABET = UP(alphabet)

// These are mapped pairwise, funnyChars[i] to normalChars[i]
const funnyChars  = [ALPHABET, greekI, accentI, puncI].join('')
const normalChars = [alphabet, greekO, accentO, puncO].join('')


// These are replaced by more than a single character:
const expandChars = ({
    'æ':  'ae',
    'Æ':  'ae',
    'œ':  'oe',
    'Œ':  'oe',
    'ß':  'ss',
    '&':  '-and-',
    '@':  '-at-',
    '.':  '-dot-',
    '#':  '-number-',
    '%':  '-percent-',
    '/':  '-slash-',
    '\\': '-slash-',
    'θ':  'th',
    'φ':  'ph',
    'χ':  'kh',
    'ψ':  'ps',
})


const buildSlugifyTable = () => {
  const table = {}

  for (const c of retainChars)
    table[c] = c

  for (const c in expandChars)
    table[c] = `-${expandChars[c]}-`

  for (const i in funnyChars)
    table[funnyChars[i]] = normalChars[i]

  return table
}

const slugifyTable = buildSlugifyTable()


const extendSlug = (chars, slug) => {
  let wasHyphen = slug.length == 0 || slug[slug.length - 1] === '-'

  for (const c of chars) {
    const isHyphen = c === '-'
    if (isHyphen && wasHyphen) continue
    slug.push(c)
    wasHyphen = isHyphen
  }
}

const slugify = input => {
  const accum = []

  let action

  for (const c of input)
    if ((action = slugifyTable[c]))
      extendSlug(action, accum)

  if (accum[accum.length - 1] === '-')
    accum.pop()

  return accum.join('')
}

slugify.table = slugifyTable
slugify.slugify = slugify
module.exports = slugify
