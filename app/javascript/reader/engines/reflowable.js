// Reflowable EPUB through foliate-js (002 research R1, R4; contracts/reader-client.md §2).
// foliate paginates the text in iframes, handles touch swipes and its own slide (the
// `animated` attribute). This adapter maps it onto the reader's interface and queues moves,
// because foliate ignores a turn while another one is running.
export async function open(container, options) {
  await import("foliate-js/view")
  const view = document.createElement("foliate-view")
  container.replaceChildren(view)
  await view.open(options.fileUrl)

  const adapter = new Reflowable(view, options)
  await adapter.start(options.startLocation, options.startProgress)
  return adapter
}

class Reflowable {
  handlesSwipes = true
  #queue = Promise.resolve()
  #documentListeners = []

  constructor(view, { animation, theme, textSize, colors, onRelocate }) {
    Object.assign(this, { view, theme, textSize, colors, onRelocate })
    this.renderer = view.renderer
    this.renderer.setAttribute("flow", "paginated")
    this.renderer.setAttribute("margin", "40px")
    this.renderer.setAttribute("gap", "6%")
    this.renderer.setAttribute("max-inline-size", "680px")
    this.setAnimation(animation)
    this.#applyStyles()

    view.addEventListener("relocate", (event) => this.#relocated(event.detail))
    view.addEventListener("load", (event) => this.#documentListeners.forEach((listener) => listener(event.detail.doc)))
  }

  // Lets the reader listen for taps and keys inside each section's iframe.
  onDocument(listener) {
    this.#documentListeners.push(listener)
    for (const { doc } of this.renderer.getContents()) listener(doc)
  }

  // Resume at the saved CFI; if it no longer resolves, at the saved fraction; else the start.
  async start(location, progress) {
    if (location) {
      try {
        await this.view.init({ lastLocation: location })
        if (this.view.lastLocation) return
      } catch (error) {
        console.warn("Saved location no longer resolves", error)
      }
    }
    if (progress > 0) await this.view.goToFraction(progress / 100)
    else await this.view.init({ showTextStart: true })
  }

  next() {
    return this.#enqueue(async () => {
      if (this.renderer.atEnd) return false
      await this.view.next()
      return true
    })
  }

  prev() {
    return this.#enqueue(async () => {
      if (this.renderer.atStart) return false
      await this.view.prev()
      return true
    })
  }

  goTo(location) {
    return this.#enqueue(() => this.view.goTo(location))
  }

  setDirection() {} // taps and arrow keys follow the direction in the reader's input

  setAnimation(animation) {
    this.renderer.toggleAttribute("animated", animation)
  }

  setTheme(theme) {
    this.theme = theme
    this.#applyStyles()
  }

  setTextSize(textSize) {
    this.textSize = textSize
    this.#applyStyles()
  }

  destroy() {
    this.view.close()
    this.view.remove()
  }

  #enqueue(move) {
    const result = this.#queue.then(move)
    this.#queue = result.catch(() => {})
    return result
  }

  #relocated(detail) {
    this.onRelocate({
      location: detail.cfi,
      progress: (detail.fraction ?? 0) * 100,
      label: detail.tocItem?.label?.trim() || "",
      atStart: this.renderer.atStart,
      atEnd: this.renderer.atEnd
    })
  }

  // Theme colours come from the reader theme tokens (shared/reader_themes.css).
  #applyStyles() {
    const { bg, fg, link } = this.colors()
    this.renderer.setStyles(`
      html {
        color-scheme: ${this.theme === "dark" ? "dark" : "light"};
        color: ${fg} !important;
        background: ${bg} !important;
      }
      body {
        color: inherit !important;
        background: transparent !important;
        font-size: ${this.textSize}% !important;
        line-height: 1.6;
      }
      a:any-link { color: ${link} !important; }
    `)
  }
}
