import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a choice changes, so settings take effect at once (FR-034).
// Typing fields wait a moment so each keystroke isn't a request.
export default class extends Controller {
  submit(event) {
    clearTimeout(this.timer)
    const typing = event?.target?.matches?.("input[type=text], input[type=search], textarea")
    this.timer = setTimeout(() => this.element.requestSubmit(), typing ? 150 : 0)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
