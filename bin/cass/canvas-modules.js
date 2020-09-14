const fs = require('fs/promises')
const {lines, isComment} = require('./util')

class ModuleItem {
  constructor(title) {
    this.title = title
  }
}

const formatDateOpts = {weekday: 'short', month: 'short', day: 'numeric'}

const formatDate = date =>
  date.toLocaleString('en-US', formatDateOpts)

const padDayNumber = num =>
  num.toString().padStart(2, '0')

class Module {
  constructor(dayNumber, title, unlockDate, dueDate) {
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

  dueDateString() {
  }

  async create(canvas) {
    return canvas.createModule(this.name(), {
      position:  this.dayNumber,
      unlock_at: this.unlockDate.toString()
    })
  }
}

const currentYear = new Date().getFullYear()

const parseDueDate = contents => {
  const match = contents.match(/^(\d\d?)\/(\d\d?)$/)
  if (!match) throw {
    description: 'Could not parse module due date',
    value: contents
  }

  return new Date(currentYear, match[1], match[2])
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

    for (const {due_date, title} of array) {
      const dueDate = parseDueDate(due_date)
      super.push(
        new Module(this.length + 1, title, unlockDate || dueDate, dueDate))
      unlockDate = dueDate
    }
  }
}

module.exports = { ModuleItem, Module, ModuleList }
