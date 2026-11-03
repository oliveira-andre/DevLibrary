import { Controller } from "@hotwired/stimulus"

// The app-wide modal (constitution Principle I, research R9). New/edit views render into the
// "modal" Turbo Frame inside this <dialog>: it opens when the frame loads and closes when a
// Turbo Stream empties the frame. Closing resets the frame so the same link opens it again,
// and Turbo never caches a page with the dialog open.
export default class extends Controller {
  connect() {
    this.frame = this.element.querySelector("turbo-frame#modal")
    this.emptied = new MutationObserver(() => {
      if (this.frame.childElementCount === 0) this.close()
    })
    this.emptied.observe(this.frame, { childList: true })
    this.beforeCache = () => this.close()
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    this.emptied.disconnect()
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }

  open() {
    if (!this.element.open) this.element.showModal()
  }

  close() {
    if (this.element.open) this.element.close()
  }

  // Runs on the dialog's "close" event, whichever way it was closed (Escape, Done, a stream).
  clear() {
    this.frame.removeAttribute("src")
    this.frame.replaceChildren()
  }

  closeOnBackdrop(event) {
    if (event.target === this.element) this.close()
  }
}
