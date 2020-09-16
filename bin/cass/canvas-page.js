const debug = require('debug')('canvas:page')
const fs = require('fs')
const util = require('util');
const {execFile} = require('child_process')

const slugify = require('./util/slugify')

const pandocToHtml = srcfile => new Promise((resolve, reject) => {
  execFile('pandoc', [srcfile, '-t', 'html'], (error, stdout, stderr) => {
    if (error)
      reject(error)
    else if (stderr)
      reject({stderr})
    else
      resolve(stdout)
  })
})

class Page {
  constructor(title, srcfile, cass) {
    this.title    = title
    this.page_url = slugify(title)
    this.srcfile  = srcfile
    this.cass     = cass
    this.html     = false
  }

  async getHtml() {
    if (!this.html) this.html = await pandocToHtml(this.srcfile)
    return this.html
  }

  async create() {
    return this.cass.canvas().putPage({
      title: this.title,
      body:  await this.getHtml(),
    })
  }
}

module.exports = Page
