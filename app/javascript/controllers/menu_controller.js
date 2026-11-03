import { Controller } from "@hotwired/stimulus"

// The account menu in the nav bar: a toggle button and a panel that closes on an outside
// click or Escape.
export default class extends Controller {
  static targets = [ "toggle", "panel" ]

  connect() {
    this.closeOnOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.hide()
    }
    document.addEventListener("click", this.closeOnOutsideClick)
    this.element.addEventListener("keydown", this.closeOnEscape)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    this.element.removeEventListener("keydown", this.closeOnEscape)
  }

  toggle() {
    this.panelTarget.hidden ? this.show() : this.hide()
  }

  show() {
    this.panelTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
  }

  hide() {
    this.panelTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
  }

  closeOnEscape = (event) => {
    if (event.key === "Escape" && !this.panelTarget.hidden) {
      this.hide()
      this.toggleTarget.focus()
    }
  }
}
