import { Controller } from "@hotwired/stimulus"

// A sideways-scrolling row (the home page's collection). Touch screens swipe it natively;
// pointer and keyboard users get previous/next buttons and the arrow keys. The buttons are
// disabled at either end.
export default class extends Controller {
  static targets = [ "row", "previous", "next" ]

  connect() {
    // Re-check the ends whenever layout changes (fonts, covers, viewport), not just on scroll.
    this.resized = new ResizeObserver(() => this.update())
    this.resized.observe(this.rowTarget)
    this.update()
  }

  disconnect() {
    this.resized.disconnect()
  }

  previous() {
    this.scroll(-1)
  }

  next() {
    this.scroll(1)
  }

  key(event) {
    if (event.key === "ArrowRight") this.scroll(1)
    else if (event.key === "ArrowLeft") this.scroll(-1)
    else return
    event.preventDefault()
  }

  update() {
    const row = this.rowTarget
    this.previousTarget.disabled = row.scrollLeft <= 1
    this.nextTarget.disabled = row.scrollLeft + row.clientWidth >= row.scrollWidth - 1
  }

  scroll(direction) {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.rowTarget.scrollBy({ left: direction * this.rowTarget.clientWidth * 0.9, behavior: reduce ? "auto" : "smooth" })
  }
}
