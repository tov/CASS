const PanoptoApi = require('./panopto-api')

const currentYear = new Date().getFullYear()

const formatDateOpts = {weekday: 'short', month: 'short', day: 'numeric'}

const formatDate = date =>
  date.toLocaleString('en-US', formatDateOpts)

const padDayNumber = num =>
  num.toString().padStart(2, '0')

const titleToPageUrl = title =>
  title.replace(/\W+/g, '-').toLowerCase()

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

class ModuleContext {
  constructor(cass, pos = [1]) {
    this.cass = cass
    this.pos  = pos
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
      return `${l0}${l1}${l2}`
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
    return this.postBody(body => canvas.createModuleItem(module_id, body))
  }

  async postBody(post) {
    const title = `(${this.cxt.slug('', 1)}) ${this.title}`
    await post({
      title,
      type:   this.type,
      indent: this.cxt.depth(),
      ...this.body,
    })
  }

  static build(opts, cxt) {
    return new (this.Types[opts.type])(opts, cxt)
  }
}

class SubSection extends ModuleItem {
  constructor({title, items: raw_items}, cxt) {
    const items = []
    let sub_cxt = cxt.indent()

    for (const each of raw_items) {
      items.push(ModuleItem.build(each, sub_cxt))
      sub_cxt = sub_cxt.next()
    }

    super(title, cxt)
    this.cxt   = cxt
    this.items = items
  }

  type = 'SubHeader'

  async postBody(post) {
    await super.postBody(post)

    const cxt = this.cxt.indent()
    for (const item of this.items) {
      await item.postBody(post)
    }
  }
}

class PageItem extends ModuleItem {
  constructor({title, page_url}, cxt) {
    page_url = page_url || titleToPageUrl(title)
    super(title, cxt, {page_url})
  }

  type = 'Page'
}

class ExternalItem extends ModuleItem {
  constructor({title, url}, cxt) {
    super(title, cxt, {external_url: url})
  }

  type = 'ExternalUrl'
}

class PanoptoItem extends ExternalItem {
  constructor({title, id}, cxt) {
    super({title}, cxt)
    this.api = new PanoptoApi(cxt.cass)
    this.id  = id
  }

  async postBody(post) {
    this.body = {external_url: this.api.embedUrl(this.id)}
    await super.postBody(post)
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
    const dueDate   = formatDate(this.dueDate)
    return `Day ${paddedDay}: ${this.title} (${dueDate})`
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
