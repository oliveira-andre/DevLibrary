import { Controller } from "@hotwired/stimulus"

// The reader's preferences as data. Whenever this element appears (page load, or a Turbo
// Stream replacing it after a settings or direction change) it tells the reader, so
// preferences only ever change through server responses (contracts/reader-client.md §1).
export default class extends Controller {
  static values = { animation: Boolean, theme: String, textSize: Number, direction: String, directionOverride: String }

  connect() {
    this.dispatch("changed")
  }
}
