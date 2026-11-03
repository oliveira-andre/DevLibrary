// Reader input (002 FR-025, research R12, contracts/reader-client.md §5). Taps on the outer
// page edges, horizontal swipes and keys become logical moves ("next"/"prev") through the
// effective reading direction: in right-to-left books the left edge and ArrowLeft go forward.
// A tap in the middle toggles the toolbar; a double tap there zooms (fixed layout).
const EDGE = 0.3
const SWIPE_MIN = 40
const SWIPE_SLOPE = Math.tan((30 * Math.PI) / 180)
const TAP_SLOP = 10
const TAP_TIME = 500
const DOUBLE_TAP = 250

export class Input {
  #listeners = []
  #gesture = null
  #pendingTap = null

  constructor(surface, { direction, isZoomed, swipes, onMove, onDrag, onDragCancel, onToggleChrome, onDoubleTap }) {
    Object.assign(this, { surface, direction, isZoomed, swipes, onMove, onDrag, onDragCancel, onToggleChrome, onDoubleTap })
    this.attach(surface)
    this.#on(window, "keydown", this.#key)
  }

  // Listens on an element, or on a book iframe's document (EPUB sections).
  attach(target) {
    this.#on(target, "pointerdown", this.#down)
    this.#on(target, "pointermove", this.#move)
    this.#on(target, "pointerup", this.#up)
    this.#on(target, "pointercancel", this.#cancel)
    if (target instanceof Document) this.#on(target, "keydown", this.#key)
  }

  destroy() {
    clearTimeout(this.#pendingTap)
    for (const [target, type, handler] of this.#listeners) target.removeEventListener(type, handler)
    this.#listeners = []
  }

  #down = (event) => {
    if (!event.isPrimary) {
      if (this.#gesture) this.#gesture.multi = true
      return
    }
    const { x, y } = point(event)
    this.#gesture = { id: event.pointerId, x0: x, y0: y, t0: event.timeStamp, multi: false, dragging: false }
  }

  #move = (event) => {
    const gesture = this.#gesture
    if (!gesture || event.pointerId !== gesture.id || gesture.multi || !this.swipes || this.isZoomed()) return

    const { x, y } = point(event)
    const dx = x - gesture.x0
    if (!gesture.dragging && Math.abs(dx) > TAP_SLOP && Math.abs(y - gesture.y0) < Math.abs(dx)) gesture.dragging = true
    if (gesture.dragging) this.onDrag?.(dx)
  }

  #up = (event) => {
    const gesture = this.#gesture
    if (!gesture || event.pointerId !== gesture.id) return
    this.#gesture = null

    const { x, y } = point(event)
    const dx = x - gesture.x0
    const dy = y - gesture.y0

    if (gesture.multi || this.isZoomed()) {
      if (gesture.dragging) this.onDragCancel?.()
      return
    }
    if (this.swipes && Math.abs(dx) >= SWIPE_MIN && Math.abs(dy) <= Math.abs(dx) * SWIPE_SLOPE) {
      // The finger moved left, so the page on the right comes into view.
      this.onMove(this.#logical(dx < 0 ? "right" : "left"), { swipe: true })
      return
    }
    if (gesture.dragging) {
      this.onDragCancel?.()
      return
    }
    if (Math.hypot(dx, dy) <= TAP_SLOP && event.timeStamp - gesture.t0 <= TAP_TIME && !event.target.closest?.("a[href]")) {
      this.#tap(x, y)
    }
  }

  #cancel = () => {
    if (this.#gesture?.dragging) this.onDragCancel?.()
    this.#gesture = null
  }

  #tap(x, y) {
    const rect = this.surface.getBoundingClientRect()
    const fraction = (x - rect.left) / rect.width
    if (fraction < EDGE || fraction > 1 - EDGE) {
      if (!this.isZoomed()) this.onMove(this.#logical(fraction < EDGE ? "left" : "right"))
      return
    }
    // Middle of the page: a second tap soon after is a double tap (zoom), not two toggles.
    if (this.#pendingTap) {
      clearTimeout(this.#pendingTap)
      this.#pendingTap = null
      this.onDoubleTap?.(x - rect.left, y - rect.top)
    } else {
      this.#pendingTap = setTimeout(() => {
        this.#pendingTap = null
        this.onToggleChrome()
      }, DOUBLE_TAP)
    }
  }

  #key = (event) => {
    if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey) return
    if (event.target.closest?.("input, textarea, select, [contenteditable], .reader__panel")) return
    if (event.key === " " && event.target.closest?.("button, a")) return

    let move
    switch (event.key) {
      case "ArrowRight": move = this.#logical("right"); break
      case "ArrowLeft": move = this.#logical("left"); break
      case "PageDown": move = "next"; break
      case "PageUp": move = "prev"; break
      case " ": move = event.shiftKey ? "prev" : "next"; break
      default: return
    }
    event.preventDefault()
    if (!this.isZoomed()) this.onMove(move)
  }

  // "right"/"left" as seen on screen → "next"/"prev" in the book.
  #logical(side) {
    const rtl = this.direction() === "rtl"
    return (side === "right") !== rtl ? "next" : "prev"
  }

  #on(target, type, handler) {
    target.addEventListener(type, handler)
    this.#listeners.push([ target, type, handler ])
  }
}

// Pointer position in the top-level page, also for events inside a book iframe.
function point(event) {
  const frame = event.view?.frameElement
  if (!frame) return { x: event.clientX, y: event.clientY }
  const rect = frame.getBoundingClientRect()
  return { x: rect.left + event.clientX, y: rect.top + event.clientY }
}
