const PanoptoApi  = require('./panopto-api')
const Exercises   = require('./exercises')
const Page        = require('./canvas-page')

const currentYear = new Date().getFullYear()

const formatDateOpts = {weekday: 'short', month: 'short', day: 'numeric'}

const formatDate = date =>
  date.toLocaleString('en-US', formatDateOpts)

const padDayNumber = num =>
  num.toString().padStart(2, '0')

const parseDueDate = contents => {
  const match = contents.match(/^(\d\d?)\/(\d\d?)$/)
  if (!match) throw {
    description: 'Could not parse module due date',
    value: contents
  }

  return new Date(currentYear, match[1] - 1, match[2])
}

const latin = index => {
  return 'abcdefghijklmnopqrstuvwxyz'[index - 1]
}

const buildTitle = (title, items) =>
  title
    ? title
    : items.map(item => item.title).join('; ')

class ModuleContext {
  constructor(cass, pos = [1]) {
    this.cass      = cass
    this.pos       = pos
    this.exercises = new Exercises(cass)
    this.panopto   = new PanoptoApi(cass)
  }

  depth() {
    return this.pos.length - 1
  }

  next() {
    const copy = new ModuleContext(this.cass, [...this.pos])
    ++copy.pos[copy.depth()]
    return copy
  }

  indent() {
    return new ModuleContext(this.cass, [...this.pos, 1])
  }

  slug(tag = '', start = 0) {
    if (tag === true) tag = this.cass.config.tag

    const pos = this.pos
    const len = pos.length

    let l0 = '', l1 = '', l2 = ''

    switch (start) {
    case 0:
      if (0 < len) l0 = padDayNumber(pos[0])
    case 1:
      if (1 < len) l1 = latin(pos[1])
    case 2:
      if (2 < len) l2 = `-${pos[2]}`
    default:
      for (let i = 3; i < len; ++i) {
        if (start <= i) {
          l2 = `${l2}.${pos[i]}`
        }
      }
      return `${tag}${l0}${l1}${l2}`
    }
  }
}

class ModuleItem {
  constructor(title, cxt, body = {}) {
    this.title = title
    this.cxt   = cxt
    this.body  = body
  }

  async create(module_id, canvas) {
    return this.postBody(
      body => canvas.createModuleItem(module_id, body),
      canvas)
  }

  async postBody(post, canvas) {
    const slug  = this.cxt.slug('', 1)
    const kind  = this.kind ? `${this.kind}: ` : ``
    const title = `(${slug}) ${kind}${this.title}`
    await post({
      title,
      type:   this.type,
      indent: this.cxt.depth(),
      ...this.body,
    })

    const exercise = this.cxt.exercises.find(this.slug)
    if (!exercise) return

    const item = new ExerciseItem(this.title, exercise.filename, this.cxt)
    await item.postBody(post, canvas)
  }

  static build(opts, cxt) {
    return new (this.Types[opts.type])(opts, cxt)
  }
}

class SubSection extends ModuleItem {
  constructor({title, items: raw_items}, cxt) {
    const items  = []

    let sub_cxt = cxt.indent()

    for (const each of raw_items) {
      items.push(ModuleItem.build(each, sub_cxt))
      sub_cxt = sub_cxt.next()
    }

    super(buildTitle(title, items), cxt)
    this.cxt   = cxt
    this.items = items
  }

  type = 'SubHeader'

  async postBody(post, canvas) {
    await super.postBody(post, canvas)

    const cxt = this.cxt.indent()
    for (const item of this.items) {
      await item.postBody(post, canvas)
    }
  }
}

class PageItem extends ModuleItem {
  constructor({title, page_url}, cxt) {
    page_url = page_url || Page.titleToUrl(title)
    super(title, cxt, {page_url})
  }

  type = 'Page'
}

class ExerciseItem extends PageItem {
  constructor(title, filename, cxt) {
    const page     = new Page(title, filename)
    const page_url = page.page_url
    super({title, page_url}, cxt)
    this.page = page
    this.kind = 'Exercise'
  }

  async postBody(post, canvas) {
    await this.page.create(canvas)
    return super.postBody(post, canvas)
  }
}

class ExternalItem extends ModuleItem {
  constructor({title, url}, cxt) {
    super(title, cxt, {external_url: url})
  }

  type = 'ExternalUrl'
}

class PanoptoItem extends ExternalItem {
  constructor({slug}, cxt) {
    slug = slug || cxt.slug(true)
    const session = cxt.panopto.findSession(slug)
    const title   = session.title
    const url     = session.embed()
    super({title, url}, cxt)
    this.kind = 'Video'
    this.slug = slug
  }
}

ModuleItem.Types = {
  sub:      SubSection,
  page:     PageItem,
  external: ExternalItem,
  video:    PanoptoItem,
}

class Module extends Array {
  constructor(dayNumber, title, unlockDate, dueDate) {
    super()
    this.dayNumber  = dayNumber
    this.title      = title
    this.unlockDate = unlockDate
    this.dueDate    = dueDate
  }

  name() {
    const paddedDay = padDayNumber(this.dayNumber)
    const title     = buildTitle(this.title, this)
    const dueDate   = formatDate(this.dueDate)

    return `Day ${paddedDay}: ${title} (${dueDate})`
  }

  async create(canvas) {
    const response = await canvas.createModule(this.name(), {
      position:  this.dayNumber,
      unlock_at: this.unlockDate.toString()
    })

    const json = await response.json()

    await canvas.publishModule(json.id)

    for (const item of this) {
      await item.create(json.id, canvas)
    }

    return json
  }
}

class ModuleList extends Array {
  static fromJSON(cass, json) {
    return this.fromArray(cass, JSON.parse(json))
  }

  static fromArray(cass, array) {
    const result = new this
    result.push(cass, ...array)
    return result
  }

  push(cass, ...array) {
    let unlockDate = this.length > 0
      ? this[this.length - 1].dueDate
      : undefined

    for (const {due_date, title, items = []} of array) {
      const dayNum  = this.length + 1
      const dueDate = parseDueDate(due_date)
      const module  = new Module(dayNum, title, unlockDate || dueDate, dueDate)
      super.push(module)

      let cxt = new ModuleContext(cass, [dayNum, 1])
      for (const item of items) {
        module.push(ModuleItem.build(item, cxt))
        cxt = cxt.next()
      }

      unlockDate = dueDate
    }
  }
}

module.exports = { ModuleItem, Module, ModuleList }
