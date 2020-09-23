const fs        = require('fs/promises')

const Page      = require('./canvas-page')
const fmt       = require('./util/fmt')
const parse     = require('./util/parse')


const attachAdvice = (actionTable, slug, ...items) => {
  let adviceList = actionTable[slug]
  if (!adviceList) adviceList = actionTable[slug] = []
  adviceList.push(...items)
}

const missingAdviceKey = () => {
  throw {
    description: 'Malformed advice',
    reason:      'Missing action key (one of before, after, or skip)',
  }
}

class ModulePlan {
  constructor(module) {
    this.module = module

    let attach  = missingAdviceKey

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
        } else {
          console.warn(`Could not find exercise for ${slug}.`)
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
    const slug  = fmt.maybeFormat(this.slug, s => ` (${s})`)
    const title = `${this.title}${slug}`

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
  constructor(page, cass, create = true) {
    const {title, page_url = Page.titleToUrl(title)} = page
    super(title, cass, {page_url})

    this._create = create
    this._page = page
  }

  type = 'Page'

  async buildBody() {
    if (this._create)
      await this._page.create()

    return super.buildBody()
  }
}

class ExerciseItem extends PageItem {
  constructor(title, slug, filename, cass) {
    const pageTitle = title
      ? `Exercise: ${title} (${slug})`
      : `Exercise for ${slug}`
    const page = new Page(pageTitle, filename, cass)
    super(page, cass)
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
    const title = fmt.joinWith(': ', 'Video', session.title)
    const url   = session.embed()
    super({title, url}, cass)
    this.slug = slug || session.slug
  }
}


const HTDP_BASE = 'https://htdp.org/2020-8-1/Book/'

const buildHtdpUri = opts => {
  const {path, part, i: raw_i, sec, ch} = opts

  const i = parseInt(raw_i)

  if (path) {
    return `${HTDP_BASE}${path}`
  }

  if (part) {
    const fragment = sec && `#%28part._sec~3a${sec}%29`
                  || ch && `#%28part._ch~3a${ch}%29`
                  || ''
    return `${HTDP_BASE}part_${part}${fragment}`
  }

  if (i) {
    const fragment = sec && `#%28part._.${sec}%29`
                  || ''
    return `${HTDP_BASE}i${i}-${i + 1}.html${fragment}`
  }

  throw {
    description: 'Bad options for HtdpItem',
    reason: 'Need `path`, `part`, or `i`(ntermezzo)'
  }
}

class HtdpItem extends ExternalItem {
  constructor({title, name, path, part, ch, i, sec}, cass) {
    title = title || `Reading: HtDP ${name}`
    const url = buildHtdpUri({path, part, ch, i, sec})
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

class ModuleLike {
  constructor(day, name, unlockDate, dueDate, cass) {
    this.day        = day
    this.name       = name
    this.unlockDate = new Date(unlockDate)
    this.dueDate    = new Date(dueDate)
    this.cass       = cass
    this.proxy      = undefined
  }

  setProxy(proxy) {
    this.proxy = proxy
  }

  isUnlocked() {
    const subject = this.proxy || this
    return subject.unlockDate < new Date
  }

  isPastDue() {
    return this.dueDate < new Date
  }
}

class ProxyModule extends ModuleLike {
  constructor(module, day, opts = {}, cass) {
    const due = module && module.dueDate
    const { id, items_count, name, position, published,
            require_sequential_progress, unlock_at, } = opts

    super(day, name, unlock_at, due, cass)
    this.canvasId = id
    this.length = items_count
    this.position = position
    this.sequential = require_sequential_progress

    if (module) module.setProxy(this)
  }

  isPosted() {
    return true
  }

  async uncreate(force = false) {
    const {canvasId, name} = this

    if (this.isUnlocked() && !force) {
      console.warn(`Not deleting unlocked module: ${name}`)
      return
    }

    await this.cass.canvas().deleteModule(canvasId, {name})
  }

  async create() {
    console.warn(`Cannot re-create remote-only module: ${name}`)
  }
}

class Module extends ModuleLike {
  constructor(day, title, unlockDate, dueDate, advice, cass) {
    const name = fmt.moduleHead(day, dueDate, title)
    super(day, name, unlockDate, dueDate, cass)
    this.advice = advice
    this.plan = new ModulePlan(this)
  }

  isPosted() {
    return this.proxy ? this.proxy.isPosted() : false
  }

  async create(force = false) {
    if (this.isPosted()) {
      if (force) {
        await this.uncreate(force)
      } else {
        console.warn(`Not reposting already-posted module: ${this.name}`)
        return
      }
    }

    if (this.isUnlocked() && !force) {
      console.warn(`Not reposting unlocked module: ${this.name}`)
      return
    }

    const canvas   = this.cass.canvas()
    const response = await canvas.createModule(this.name, {
      position: this.day,
      unlock_at: this.unlockDate.toISOString(),
      require_sequential_progress: true,
    })

    const json = await response.json()
    await this.plan.execute(json.id)
    await canvas.publishModule(json.id)
    return json
  }

  async uncreate(force = false) {
    if (this.proxy)
      await this.proxy.uncreate(force)
    else
      console.warn(`Not deleting unposted module: ${this.name}`)
  }
}

class ModuleList {
  constructor(cass) {
    this.cass     = cass
    this._modules = []
  }

  getModules() {
    return this._modules
  }

  getModuleForDay(i) {
    return this._modules[i - 1]
  }

  setModuleForDay(i, module) {
    this._modules[i - 1] = module
  }

  async load() {
    const remoteData = this.fetchRemote()
    const localData  = this.readLocal()

    await this.loadLocal(await localData)
    await this.loadRemote(await remoteData)

    return this
  }

  async loadLocal(data) {
    data = data || await this.readLocal()
    const modules = this._modules

    let day = 1
    let prev = undefined

    for (let {title, date, unlock, advice = []} of data) {
      const due = parse.dueDate(date)
      unlock = unlock ? parse.dueDate(unlock) : prev || due

      this.setModuleForDay(day,
        new Module(day, title, unlock, due, advice, this.cass))

      ++day
      prev = due
    }

    return this
  }

  async loadRemote(data) {
    data = data || await this.fetchRemote()
    const modules = this._modules

    for (const each of data) {
      const match  = each.name.match(/^Day (\d+):/) || []
      const day    = parseInt(match[1]) || modules.length + 1
      const module = this.getModuleForDay(day)
      const proxy  = new ProxyModule(module, day, each, this.cass)
      if (!module) this.setModuleForDay(day, proxy)
    }

    return this
  }

  async readLocal() {
    const json = await fs.readFile(this.cass.base('modules.json'), 'utf8')
    return JSON.parse(json)
  }

  async fetchRemote() {
    return this.cass.canvas().getModules()
  }
}

module.exports = { ModuleItem, Module, ModuleList }
