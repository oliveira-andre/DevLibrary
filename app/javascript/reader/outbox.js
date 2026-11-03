// The reading-position outbox (002 FR-023, research R5, contracts/reader-client.md §6).
//
// Holds the one position that hasn't reached the server yet, in localStorage so it
// survives a closed tab, and keeps sending it until the server answers. The server stays
// the source of truth: its newest-wins rule makes late and repeated saves harmless.
const RETRY_START = 1000
const RETRY_MAX = 30000

export class Outbox {
  constructor({ url, userId, bookId, onStatus = () => {} }) {
    this.url = url
    this.key = `devlibrary:reading-position:${userId}:${bookId}`
    this.onStatus = onStatus
    this.entry = this.#load()
    this.sending = false
    this.paused = false
    this.delay = RETRY_START

    this.flush = this.flush.bind(this)
    this.flushWhenHidden = () => { if (document.visibilityState === "hidden") this.flush() }
    window.addEventListener("online", this.flush)
    window.addEventListener("pagehide", this.flush)
    document.addEventListener("visibilitychange", this.flushWhenHidden)
  }

  // The unsent position, if any: { location, progress, read_at }.
  pending() {
    return this.entry
  }

  record({ location, progress }) {
    this.entry = { location, progress, read_at: new Date().toISOString() }
    this.#store()
    this.flush()
  }

  async flush() {
    if (!this.entry || this.sending || this.paused) return
    clearTimeout(this.retryTimer)
    const entry = this.entry
    this.sending = true

    try {
      const response = await fetch(this.url, {
        method: "PATCH",
        keepalive: true,
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content ?? ""
        },
        body: JSON.stringify(entry)
      })
      this.#handle(response.status, entry)
    } catch {
      this.#retry()
    } finally {
      this.sending = false
    }

    // A newer page turn arrived while this one was in flight.
    if (this.entry && this.entry !== entry && !this.paused) this.flush()
  }

  destroy() {
    clearTimeout(this.retryTimer)
    window.removeEventListener("online", this.flush)
    window.removeEventListener("pagehide", this.flush)
    document.removeEventListener("visibilitychange", this.flushWhenHidden)
  }

  #handle(status, entry) {
    if (status >= 200 && status < 300) {
      this.delay = RETRY_START
      this.#drop(entry)
    } else if (status === 401) {
      this.paused = true // keep the entry; it is sent after signing in again
      this.onStatus("signed-out")
    } else if (status === 403) {
      this.paused = true
      this.#drop(entry)
      this.onStatus("blocked")
    } else if (status === 404) {
      this.paused = true
      this.#drop(entry)
      this.onStatus("unavailable")
    } else if (status === 422) {
      this.#drop(entry) // a locator the server can't take must not loop forever
    } else {
      this.#retry()
    }
  }

  #drop(entry) {
    if (this.entry?.read_at === entry.read_at) {
      this.entry = null
      this.#store()
    }
  }

  #retry() {
    clearTimeout(this.retryTimer)
    this.retryTimer = setTimeout(this.flush, this.delay)
    this.delay = Math.min(this.delay * 2, RETRY_MAX)
  }

  #load() {
    try {
      return JSON.parse(localStorage.getItem(this.key)) ?? null
    } catch {
      return null
    }
  }

  #store() {
    try {
      if (this.entry) localStorage.setItem(this.key, JSON.stringify(this.entry))
      else localStorage.removeItem(this.key)
    } catch {
      // Storage can be unavailable (private mode, quota); the entry still lives in memory.
    }
  }
}
