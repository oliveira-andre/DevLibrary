// The fixed-layout pager for PDF and comics (002 research R1, R4, R12; contracts/reader-client.md §2).
//
// The current page and its neighbours sit side by side in reading order (right-to-left books
// put the next page on the left). A turn either slides the track 250 ms or swaps at once; new
// input lands a running slide first, so quick turns never skip a page or stop half-way. Pages
// zoom with pinch, double tap, Ctrl/⌘ + wheel and the zoom buttons; turning pauses while zoomed.
// Sources only know how to draw one page (sources/pdf_source.js, sources/cbz_source.js).
const SLIDE_MS = 250
const SLIDE_EASING = "cubic-bezier(0.22, 1, 0.36, 1)"
const MAX_ZOOM = 4
const KEEP = 2 // pages kept around the current one

export async function open(container, options) {
  const sourceModule = options.format === "pdf" ? "reader/sources/pdf_source" : "reader/sources/cbz_source"
  const { open: openSource } = await import(sourceModule)
  const pager = new Pager(container, await openSource(options.fileUrl), options)
  await pager.start(options.startLocation)
  return pager
}

class Pager {
  handlesSwipes = false
  #pages = new Map() // index → { element, content, ready }
  #running = null // the slide in progress: { animation, done }
  #dragOffset = null
  #zoom = { scale: 1, x: 0, y: 0 }
  #cleanup = []

  constructor(container, source, { direction, animation, onRelocate, onTurning = () => {}, onZoom = () => {} }) {
    Object.assign(this, { source, direction, animation, onRelocate, onTurning, onZoom })
    this.index = 0
    this.viewport = element("div", "pager")
    this.track = element("div", "pager__track")
    this.viewport.append(this.track)
    container.replaceChildren(this.viewport)

    const pager = this
    this.zoom = {
      in: () => this.#zoomAround(this.#zoom.scale * 1.5),
      out: () => this.#zoomAround(this.#zoom.scale / 1.5),
      fit: () => this.#setZoom(1, 0, 0),
      toggleAt: (x, y) => this.isZoomed ? this.#setZoom(1, 0, 0) : this.#zoomAround(2, { x, y }),
      get isZoomed() { return pager.isZoomed }
    }
    this.#bindZoomGestures()

    let resizeTimer
    const resized = new ResizeObserver(() => {
      clearTimeout(resizeTimer)
      resizeTimer = setTimeout(() => this.#rerender(), 150)
    })
    resized.observe(this.viewport)
    this.#cleanup.push(() => { resized.disconnect(); clearTimeout(resizeTimer) })
  }

  get pageCount() {
    return this.source.pageCount
  }

  get isZoomed() {
    return this.#zoom.scale > 1.01
  }

  async start(location) {
    const page = parseInt(location, 10)
    this.index = Number.isFinite(page) ? clamp(page - 1, 0, this.pageCount - 1) : 0
    await this.#ensure(this.index).ready
    this.#layout()
    this.#prefetch()
    this.#emit()
  }

  next() {
    return this.#turn(1)
  }

  prev() {
    return this.#turn(-1)
  }

  goTo(location) {
    const page = parseInt(location, 10)
    if (!Number.isFinite(page)) return false
    this.#finishSlide()
    this.#ensure(clamp(page - 1, 0, this.pageCount - 1))
    this.#commit(clamp(page - 1, 0, this.pageCount - 1))
    return true
  }

  // A swipe in progress: the track follows the finger (only when turns are animated).
  drag(dx) {
    if (!this.animation || this.isZoomed) return
    this.#finishSlide()
    this.#dragOffset = dx
    this.track.style.transform = `translateX(${dx}px)`
  }

  cancelDrag() {
    const from = this.#dragOffset
    this.#dragOffset = null
    if (from) this.#slide(from, 0, () => {})
  }

  swipe(step) {
    const from = this.#dragOffset ?? 0
    this.#dragOffset = null
    return this.#turn(step, from)
  }

  setDirection(direction) {
    this.#finishSlide()
    this.direction = direction
    this.#layout()
  }

  setAnimation(animation) {
    this.animation = animation
    if (!animation) this.#finishSlide()
  }

  setTheme() {} // the page surround comes from the theme tokens in CSS
  setTextSize() {} // fixed-layout pages have no text to reflow

  destroy() {
    this.#finishSlide()
    for (const cleanup of this.#cleanup) cleanup()
    for (const index of this.#pages.keys()) this.source.release(index)
    this.source.destroy()
    this.viewport.remove()
  }

  #turn(step, fromPx = 0) {
    this.#finishSlide()
    const target = this.index + step
    if (target < 0 || target >= this.pageCount) {
      if (fromPx) this.#slide(fromPx, 0, () => {})
      else this.track.style.transform = ""
      return false
    }

    this.#ensure(target)
    if (!this.animation) {
      this.#commit(target)
      return true
    }
    const to = -step * this.#sign() * this.viewport.clientWidth
    this.#slide(fromPx, to, () => this.#commit(target))
    return true
  }

  #slide(from, to, done) {
    this.onTurning(true)
    const animation = this.track.animate(
      [ { transform: `translateX(${from}px)` }, { transform: `translateX(${to}px)` } ],
      { duration: SLIDE_MS, easing: SLIDE_EASING }
    )
    this.#running = { animation, done }
    animation.onfinish = () => {
      if (this.#running?.animation === animation) this.#completeSlide()
    }
    // "finish" arrives on an animation frame, which a backgrounded tab may never paint;
    // the turn (and its saved position) must land anyway.
    setTimeout(() => {
      if (this.#running?.animation === animation) this.#finishSlide()
    }, SLIDE_MS + 50)
  }

  // Lands a running slide at once (new input arrived, or the animation was switched off).
  #finishSlide() {
    if (!this.#running) return
    this.#running.animation.cancel()
    this.#completeSlide()
  }

  #completeSlide() {
    const { done } = this.#running
    this.#running = null
    this.track.style.transform = ""
    this.onTurning(false)
    done()
  }

  #commit(target) {
    this.index = target
    this.track.style.transform = ""
    this.#setZoom(1, 0, 0)
    this.#layout()
    this.#evict()
    this.#prefetch()
    this.#emit()
  }

  #emit() {
    const count = this.pageCount
    const page = this.index + 1
    this.onRelocate({
      location: String(page),
      progress: count > 1 ? (this.index / (count - 1)) * 100 : 100,
      label: `Page ${page} of ${count}`,
      atStart: this.index === 0,
      atEnd: this.index === count - 1
    })
  }

  // Positions every kept page relative to the current one, in reading order.
  #layout() {
    for (const [ index, page ] of this.#pages) {
      const offset = index - this.index
      page.element.style.transform = `translateX(${offset * this.#sign() * 100}%)`
      page.element.hidden = Math.abs(offset) > 1
      page.element.setAttribute("aria-hidden", String(offset !== 0))
    }
  }

  #ensure(index) {
    if (this.#pages.has(index)) return this.#pages.get(index)

    const pageElement = element("div", "pager__page")
    const content = element("div", "pager__content")
    pageElement.append(content)
    this.track.append(pageElement)

    const page = { element: pageElement, content }
    page.ready = this.source
      .render(index, { width: this.viewport.clientWidth, height: this.viewport.clientHeight, pixelRatio: Math.min(window.devicePixelRatio || 1, 2) })
      .then((drawn) => { if (this.#pages.get(index) === page) content.replaceChildren(drawn) })
    this.#pages.set(index, page)
    this.#layout()
    return page
  }

  #prefetch() {
    if (this.index > 0) this.#ensure(this.index - 1)
    if (this.index < this.pageCount - 1) this.#ensure(this.index + 1)
  }

  #evict() {
    for (const [ index, page ] of this.#pages) {
      if (Math.abs(index - this.index) > KEEP) {
        page.element.remove()
        this.#pages.delete(index)
        this.source.release(index)
      }
    }
  }

  // After a resize the drawn pages no longer fit: draw them again at the new size.
  #rerender() {
    for (const [ index, page ] of this.#pages) {
      page.element.remove()
      this.source.release(index)
    }
    this.#pages.clear()
    this.#ensure(this.index)
    this.#prefetch()
    this.#setZoom(1, 0, 0)
  }

  #sign() {
    return this.direction === "rtl" ? -1 : 1
  }

  // --- Zoom and pan (FR-028) -------------------------------------------------------------

  #setZoom(scale, x, y) {
    const wasZoomed = this.isZoomed
    const width = this.viewport.clientWidth
    const height = this.viewport.clientHeight
    scale = clamp(scale, 1, MAX_ZOOM)
    this.#zoom = {
      scale,
      x: clamp(x, width - width * scale, 0),
      y: clamp(y, height - height * scale, 0)
    }
    const current = this.#pages.get(this.index)
    if (current) {
      current.content.style.transform = scale === 1 ? "" : `translate(${this.#zoom.x}px, ${this.#zoom.y}px) scale(${scale})`
    }
    if (wasZoomed !== this.isZoomed) this.onZoom(this.isZoomed)
  }

  // Zooms keeping `point` (viewport coordinates; default the centre) under the same spot.
  #zoomAround(scale, point = { x: this.viewport.clientWidth / 2, y: this.viewport.clientHeight / 2 }) {
    const { scale: current, x, y } = this.#zoom
    const next = clamp(scale, 1, MAX_ZOOM)
    this.#setZoom(next, point.x - ((point.x - x) * next) / current, point.y - ((point.y - y) * next) / current)
  }

  #bindZoomGestures() {
    const pointers = new Map()
    let pinch = null
    let pan = null
    const local = (event) => {
      const rect = this.viewport.getBoundingClientRect()
      return { x: event.clientX - rect.left, y: event.clientY - rect.top }
    }

    this.#listen(this.viewport, "pointerdown", (event) => {
      pointers.set(event.pointerId, local(event))
      if (pointers.size === 2) {
        const [ a, b ] = [ ...pointers.values() ]
        pinch = { distance: distance(a, b), scale: this.#zoom.scale, x: this.#zoom.x, y: this.#zoom.y, centre: midpoint(a, b) }
        pan = null
      } else if (pointers.size === 1 && this.isZoomed) {
        pan = { start: local(event), x: this.#zoom.x, y: this.#zoom.y }
      }
    })

    this.#listen(this.viewport, "pointermove", (event) => {
      if (!pointers.has(event.pointerId)) return
      pointers.set(event.pointerId, local(event))
      if (pinch && pointers.size >= 2) {
        const [ a, b ] = [ ...pointers.values() ]
        const scale = clamp((pinch.scale * distance(a, b)) / pinch.distance, 1, MAX_ZOOM)
        const { centre } = pinch
        this.#setZoom(scale, centre.x - ((centre.x - pinch.x) * scale) / pinch.scale, centre.y - ((centre.y - pinch.y) * scale) / pinch.scale)
      } else if (pan) {
        const now = local(event)
        this.#setZoom(this.#zoom.scale, pan.x + now.x - pan.start.x, pan.y + now.y - pan.start.y)
      }
    })

    const release = (event) => {
      pointers.delete(event.pointerId)
      if (pointers.size < 2) pinch = null
      if (pointers.size === 0) pan = null
    }
    this.#listen(this.viewport, "pointerup", release)
    this.#listen(this.viewport, "pointercancel", release)

    // Trackpad pinch arrives as Ctrl + wheel; Ctrl/⌘ + mouse wheel zooms too.
    this.#listen(this.viewport, "wheel", (event) => {
      if (!event.ctrlKey && !event.metaKey) return
      event.preventDefault()
      this.#zoomAround(this.#zoom.scale * Math.exp(-event.deltaY * 0.01), local(event))
    }, { passive: false })
  }

  #listen(target, type, handler, options) {
    target.addEventListener(type, handler, options)
    this.#cleanup.push(() => target.removeEventListener(type, handler, options))
  }
}

function element(tag, className) {
  const node = document.createElement(tag)
  node.className = className
  return node
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max)
}

function distance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y)
}

function midpoint(a, b) {
  return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }
}
