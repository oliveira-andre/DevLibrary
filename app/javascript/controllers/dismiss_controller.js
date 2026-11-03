import { Controller } from "@hotwired/stimulus"

// Flash toasts remove themselves after a few seconds, or at once when tapped.
export default class extends Controller {
  static values = { after: { type: Number, default: 6000 } }

  connect() {
    this.timer = setTimeout(() => this.remove(), this.afterValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  remove() {
    this.element.remove()
  }
}
