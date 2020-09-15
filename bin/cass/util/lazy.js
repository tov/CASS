class Lazy {
  constructor(thunk, ready = false) {
    if (ready) this._value = thunk
    else       this._thunk = thunk
    this.isReady = ready
  }

  force() {
    if (!this.isReady) {
      this._value  = (this._thunk)()
      this.isReady = true
      delete this._thunk
    }

    return this._value
  }
}

module.exports = Lazy
