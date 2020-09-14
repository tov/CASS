const fs = require('fs')
const util = require('util');
const {execFile} = require('child_process')

const titleToPageUrl = title =>
  title.replace(/\W+/g, '-').toLowerCase()

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
  constructor(title, srcfile) {
    this.title   = title
    this.url     = titleToPageUrl(title)
    this.srcfile = srcfile
    this.html    = false
  }

  static titleToUrl = titleToPageUrl

  async getHtml() {
    if (!this.html) this.html = await pandocToHtml(this.srcfile)
    return this.html
  }

  async create(canvas) {
    return canvas.putPage({
      title: this.title,
      body:  await this.getHtml(),
    })
  }
}

module.exports = Page
