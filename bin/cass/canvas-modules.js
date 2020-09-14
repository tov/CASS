const {buildUri} = require('./rest-client')

// TODO: extract this
const panoptoEmbedBase =
  'https://northwestern.hosted.panopto.com/Panopto/Pages/Embed.aspx'
const buildPanoptoUrl = (id, {
  autoplay = false,
  offerviewer = true,
  showtitle = false,
  showbrand = false,
  interactivity = 'all',
} = {}) => {
    const type = `#{opts.type}Item`
  return buildUri(panoptoEmbedBase, null, {
    id, autoplay, offerviewer, showtitle, showbrand, interactivity
  })
}

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

class ModuleItem {
  constructor(title) {
    this.title = title
  }

  indent = 1

  async create(module_id, canvas) {
    return canvas.createModuleItem(module_id, this.postBody())
  }

  postBody() {
    return {
      type:   this.type,
      title:  this.title,
      indent: this.indent,
    }
  }

  static build(opts = {}) {
    return new (this.Types[opts.type])(opts.title, opts)
  }
}

class SubHeaderItem extends ModuleItem {
  indent = 0
  type = 'SubHeader'
}

class PageItem extends ModuleItem {
  constructor(title, {url}) {
    super(title)
    this.page_url = url
  }

  type = 'Page'

  postBody() {
    return {
      ...super.postBody(),
      page_url: this.page_url,
    }
  }
}

class ExternalItem extends ModuleItem {
  constructor(title, {url}) {
    super(title)
    this.external_url = url
  }

  type = 'ExternalUrl'

  postBody() {
    return {
      ...super.postBody(),
      external_url: this.external_url,
    }
  }
}

class PanoptoItem extends ExternalItem {
  constructor(title, {id}) {
    super(title, {url: buildPanoptoUrl(id)})
  }
}

ModuleItem.Types = {
  subhead:  SubHeaderItem,
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
  static fromJSON(json) {
    return this.fromArray(JSON.parse(json))
  }

  static fromArray(array) {
    const result = new this
    result.push(...array)
    return result
  }

  push(...array) {
    let unlockDate = this.length > 0
      ? this[this.length - 1].dueDate
      : undefined

    for (const {due_date, title, items = []} of array) {
      const dueDate = parseDueDate(due_date)
      const module =
        new Module(this.length + 1, title, unlockDate || dueDate, dueDate)
      super.push(module)

      for (const item of items) {
        module.push(ModuleItem.build(item))
      }

      unlockDate = dueDate
    }
  }
}

module.exports = { ModuleItem, Module, ModuleList }
