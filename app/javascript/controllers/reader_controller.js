import { Controller } from "@hotwired/stimulus"

// The in-app reader (002 US3, US4; contracts/reader-client.md).
//
// Loads the engine for the book's format, resumes at the newer of the server's saved position
// and any position still waiting in the outbox, turns pages from taps, swipes and keys, and
// hands every settled position to the outbox. Engines only draw pages; position, direction
// and settings travel through Rails endpoints (constitution Principle I exception).
export default class extends Controller {
  static targets = [ "surface", "label", "percent", "progress", "progressFill", "banner", "toast", "panel", "settingsToggle", "zoomControls" ]
  static values = {
    format: String, fileUrl: String, positionUrl: String, bookId: String, userId: String,
    startLocation: String, startProgress: Number, startReadAt: String, signInUrl: String
  }

  async connect() {
    if (this.element.dataset.readerState !== "loading") return

    this.preferences = readPreferences(document.getElementById("reader_preferences"))
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.motionChanged = () => this.#applyAnimation()
    this.reducedMotion.addEventListener("change", this.motionChanged)

    try {
      const [ { Outbox }, { Input } ] = await Promise.all([ import("reader/outbox"), import("reader/input") ])
      this.outbox = new Outbox({
        url: this.positionUrlValue, userId: this.userIdValue, bookId: this.bookIdValue,
        onStatus: (status) => this.#outboxStatus(status)
      })

      const engine = this.formatValue === "epub" ? "reader/engines/reflowable" : "reader/engines/fixed_layout"
      const { open } = await import(engine)
      const start = this.#startPosition()
      this.adapter = await open(this.surfaceTarget, {
        format: this.formatValue,
        fileUrl: this.fileUrlValue,
        startLocation: start.location,
        startProgress: start.progress,
        direction: this.preferences.direction,
        animation: this.#animated(),
        theme: this.preferences.theme,
        textSize: this.preferences.textSize,
        colors: () => this.#themeColors(),
        onRelocate: (detail) => this.#relocated(detail),
        onTurning: (turning) => this.element.toggleAttribute("data-reader-turning", turning),
        onZoom: (zoomed) => { this.element.dataset.readerZoomed = String(zoomed) }
      })
      if (!this.element.isConnected) return this.adapter.destroy()

      this.input = new Input(this.surfaceTarget, {
        direction: () => this.preferences.direction,
        isZoomed: () => Boolean(this.adapter.zoom?.isZoomed),
        swipes: !this.adapter.handlesSwipes,
        onMove: (direction, options) => this.move(direction, options),
        onDrag: (dx) => this.adapter.drag?.(dx),
        onDragCancel: () => this.adapter.cancelDrag?.(),
        onToggleChrome: () => this.toggleChrome(),
        onDoubleTap: (x, y) => this.adapter.zoom?.toggleAt(x, y)
      })
      this.adapter.onDocument?.((doc) => this.input.attach(doc))
      this.zoomControlsTarget.hidden = !this.adapter.zoom
      this.#applyAnimation()
      this.element.dataset.readerState = "ready"
      // Keys turn pages right away; no focus ring, since nobody tabbed here.
      this.surfaceTarget.focus({ preventScroll: true, focusVisible: false })
    } catch (error) {
      console.error(error)
      this.element.dataset.readerState = "error"
    }
  }

  disconnect() {
    this.reducedMotion?.removeEventListener("change", this.motionChanged)
    this.outbox?.flush()
    this.outbox?.destroy()
    this.input?.destroy()
    this.adapter?.destroy()
    clearTimeout(this.toastTimer)
  }

  async move(direction, { swipe = false } = {}) {
    if (!this.adapter) return
    const step = direction === "next" ? 1 : -1
    const moved = await (swipe && this.adapter.swipe ? this.adapter.swipe(step) : this.adapter[direction]())
    if (moved === false) this.#toast(direction === "next" ? "You've reached the end" : "This is the beginning")
  }

  // A settings or direction change arrived (reader_preferences was replaced).
  applyPreferences(event) {
    const previous = this.preferences ?? {}
    this.preferences = readPreferences(event.target)
    this.element.dataset.readerTheme = this.preferences.theme
    if (!this.adapter) return

    if (this.preferences.theme !== previous.theme) this.adapter.setTheme(this.preferences.theme)
    if (this.preferences.textSize !== previous.textSize) this.adapter.setTextSize(this.preferences.textSize)
    if (this.preferences.direction !== previous.direction) this.adapter.setDirection(this.preferences.direction)
    this.#applyAnimation()
  }

  toggleSettings() {
    const open = this.panelTarget.hidden
    this.panelTarget.hidden = !open
    this.settingsToggleTarget.setAttribute("aria-expanded", String(open))
  }

  toggleChrome() {
    this.element.dataset.readerChrome = this.element.dataset.readerChrome === "hidden" ? "shown" : "hidden"
  }

  zoomIn() {
    this.adapter?.zoom?.in()
  }

  zoomOut() {
    this.adapter?.zoom?.out()
  }

  zoomFit() {
    this.adapter?.zoom?.fit()
  }

  // The server's saved position, unless the outbox holds a newer one that never arrived
  // (pages turned offline before the tab closed, or after the session ended).
  #startPosition() {
    const pending = this.outbox.pending()
    const savedAt = this.startReadAtValue ? Date.parse(this.startReadAtValue) : 0
    if (pending && Date.parse(pending.read_at) > savedAt) {
      return { location: pending.location ?? "", progress: Number(pending.progress) || 0 }
    }
    return { location: this.startLocationValue, progress: this.startProgressValue }
  }

  #relocated({ location, progress, label }) {
    // foliate reports a section boundary before layout with no usable fraction; skip it.
    if (!location || !Number.isFinite(progress)) return

    const percent = Math.round(progress)
    this.element.dataset.readerLocation = location
    this.element.dataset.readerProgress = progress.toFixed(2)
    this.labelTarget.textContent = label
    this.percentTarget.textContent = `${percent}%`
    this.progressFillTarget.style.width = `${progress}%`
    this.progressTarget.setAttribute("aria-valuenow", String(percent))
    this.outbox.record({ location, progress: Number(progress.toFixed(2)) })
  }

  #outboxStatus(status) {
    if (status === "signed-out") this.bannerTarget.hidden = false
    else this.element.dataset.readerState = status // "blocked" or "unavailable"
  }

  #animated() {
    return this.preferences.animation && !this.reducedMotion.matches
  }

  #applyAnimation() {
    const animated = this.#animated()
    this.element.dataset.readerAnimation = animated ? "slide" : "none"
    this.adapter?.setAnimation(animated)
  }

  #themeColors() {
    const style = getComputedStyle(this.element)
    const token = (name) => style.getPropertyValue(name).trim()
    return { bg: token("--reader-bg"), fg: token("--reader-fg"), link: token("--reader-link") }
  }

  #toast(message) {
    this.toastTarget.textContent = message
    this.toastTarget.classList.add("is-visible")
    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => this.toastTarget.classList.remove("is-visible"), 2500)
  }
}

function readPreferences(element) {
  const data = element.dataset
  return {
    animation: data.readerPreferencesAnimationValue === "true",
    theme: data.readerPreferencesThemeValue,
    textSize: Number(data.readerPreferencesTextSizeValue),
    direction: data.readerPreferencesDirectionValue
  }
}
