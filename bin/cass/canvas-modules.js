const debug     = require('debug')('canvas-modules')

const Page      = require('./canvas-page')
const fmt       = require('./util/fmt')
const parse     = require('./util/parse')


const attachAdvice = (actionTable, slug, ...items) => {
  let adviceList = actionTable[slug]
  if (!adviceList) adviceList = actionTable[slug] = []
  adviceList.push(...items)
}

class ModulePlan {
  constructor(module) {
    this.module = module

    let attach  = this.addBeforeAdvice('all')

    for (const {before, after, skip, ...opts} of module.advice) {
      if (before)     attach = this.addBeforeAdvice(before)
      else if (after) attach = this.addAfterAdvice(after)
      else if (skip)  attach = this.addSkipAdvice(skip)

      attach(() => ModuleItem.build(opts, this.module.cass))
    }
  }

  _before_advice = {}
  _after_advice = {}
  _skip_advice = {}

  addBeforeAdvice(slug) {
    return mk => attachAdvice(this._before_advice, slug, mk())
  }

  addAfterAdvice(slug) {
    return mk => attachAdvice(this._after_advice, slug, mk())
  }

  addSkipAdvice(slug) {
    return _ => this._skip_advice[slug] = true
  }

  async execute(module_id) {
    const {cass, day} = this.module
    const panopto   = cass.panopto()
    const exercises = cass.exercises()

    const module = panopto.byDay[day]
    if (!module) return

    for (let i = 0; i < module.length; ++i) {
      const section = module[i]
      if (!section) continue

      const items  = []

      for (let j = 0; j < section.length; ++j) {
        const session = section[j]
        if (!session) continue

        const {slug, title} = session
        if (this._skip_advice[slug]) continue

        const before = this._before_advice[slug]
        if (before) items.push(...before)

        items.push(new PanoptoItem({session, slug}, cass))

        const exercise = exercises.find(slug)
        if (exercise) {
          items.push(new ExerciseItem(title, slug, exercise.filename, cass))
        }

        const after = this._after_advice[slug]
        if (after) items.push(...after)
      }

      const title = `Part (${fmt.section(i)})`
      await new SubHeaderItem({title}, cass).create(module_id)

      for (const item of items) {
        await item.create(module_id)
      }
    }
  }
}


class ModuleItem {
  constructor(title, cass, body = {}) {
    this.title = title
    this.cass  = cass
    this.body  = body
  }

  static build(opts, cass) {
    return new (this.Types[opts.type])(opts, cass)
  }

  indent = 1

  async create(module_id) {
    const canvas = this.cass.canvas()
    const body = await this.buildBody()
    return canvas.createModuleItem(module_id, body)
  }

  async buildBody() {
    const kind  = fmt.maybeFormat(this.kind, s => `${s}: `)
    const slug  = fmt.maybeFormat(this.slug, s => ` (${s})`)
    const title = `${kind}${this.title}${slug}`

    return {
      title,
      type:   this.type,
      indent: this.indent,
      ...this.body,
    }
  }
}


class SubHeaderItem extends ModuleItem {
  constructor({title}, cass) {
    super(title, cass)
  }

  indent = 0
  type   = 'SubHeader'
}


class PageItem extends ModuleItem {
  constructor({title, page_url}, cass) {
    page_url = page_url || Page.titleToUrl(title)
    super(title, cass, {page_url})
  }

  type = 'Page'
}

class ExerciseItem extends PageItem {
  constructor(title, slug, filename, cass) {
    const page = new Page(title, filename, cass)
    super(page, cass)
    this.page = page
    this.kind = 'Exercise'
    this.slug = slug
  }

  async buildBody() {
    await this.page.create()
    return super.buildBody()
  }
}

class ExternalItem extends ModuleItem {
  constructor({title, url}, cass) {
    super(title, cass, {external_url: url})
  }

  type = 'ExternalUrl'
}

class PanoptoItem extends ExternalItem {
  constructor({session, slug}, cass) {
    session = session || cass.panopto.findBySlug(slug, true)
    const title = session.title
    const url   = session.embed()
    super({title, url}, cass)
    this.kind = 'Video'
    this.slug = slug || session.slug
  }
}

const HTDP_BASE = 'https://htdp.org/2020-8-1/Book/'

class HtdpItem extends ExternalItem {
  constructor({path, section}, cass) {
    const title = `Reading: HtDP ${section}`
    const url   = `${HTDP_BASE}${path}`
    super({title, url}, cass)
  }
}

ModuleItem.Types = {
  page:     PageItem,
  external: ExternalItem,
  video:    PanoptoItem,
  htdp:     HtdpItem,
  head:     SubHeaderItem,
}

class Module extends Array {
  constructor(day, title, unlockDate, dueDate, advice, cass) {
    super()
    this.day        = day
    this.title      = title
    this.unlockDate = unlockDate
    this.dueDate    = dueDate
    this.advice     = advice
    this.cass       = cass
    this.plan       = new ModulePlan(this)
  }

  name() {
    return fmt.moduleHead(this.day, this.dueDate, this.title)
  }

  async create() {
    const canvas   = this.cass.canvas()
    const response = await canvas.createModule(this.name(), {
      position:  this.day,
      unlock_at: this.unlockDate.toString()
    })

    const json = await response.json()
    await canvas.publishModule(json.id)
    await this.plan.execute(json.id)
    return json
  }
}

class ModuleList extends Array {
  constructor(cass) {
    super()
    this.cass = cass
  }

  static fromJSON(cass, json) {
    return this.fromArray(cass, JSON.parse(json))
  }

  static fromArray(cass, array) {
    const result = new this(cass)
    result.push(...array)
    return result
  }

  push(...array) {
    let day = this.length + 1

    for (const {date, unlock, title, advice = []} of array) {
      const dueDate    = parse.dueDate(date)
      const unlockDate = unlock
        ? parse.dueDate(unlock)
        : this[this.length - 1] || dueDate
      super.push(new Module(day, title, unlockDate, dueDate, advice, this.cass))
      ++day
    }
  }
}

module.exports = { ModuleItem, Module, ModuleList }
