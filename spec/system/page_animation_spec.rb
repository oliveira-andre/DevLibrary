require "rails_helper"

RSpec.describe "Page-turn animation", type: :system do
  on_each_viewport do
    let(:reader) { create(:user) }
    let(:pdf) { create(:book, :published, file_fixture_name: "reader/text-6-pages.pdf") }

    def open_reader(book)
      visit book_reader_path(book)
      wait_for_reader
    end

    # Records whether a turn was animated and how long the page took to change.
    def watch_turns
      page.execute_script(<<~JS)
        const reader = document.getElementById("reader")
        window.__turning = false
        window.__keyAt = null
        window.__changedAfter = null
        window.__slides = []
        window.addEventListener("keydown", () => { window.__keyAt = performance.now() }, true)
        new MutationObserver((records) => {
          for (const record of records) {
            if (record.attributeName === "data-reader-turning" && reader.hasAttribute("data-reader-turning")) window.__turning = true
            if (record.attributeName === "data-reader-location" && window.__keyAt && window.__changedAfter === null) {
              window.__changedAfter = performance.now() - window.__keyAt
            }
          }
        }).observe(reader, { attributes: true })
        const animate = Element.prototype.animate
        Element.prototype.animate = function (keyframes, options) {
          if (this.classList.contains("pager__track")) window.__slides.push(keyframes.map((frame) => frame.transform))
          return animate.call(this, keyframes, options)
        }
      JS
    end

    def last_slide_end
      page.evaluate_script("window.__slides.at(-1)")&.last.to_s[/-?\d+(\.\d+)?/].to_f
    end

    it "slides from page to page for a new account" do
      sign_in_and_wait_as(reader)
      open_reader(pdf)
      expect(page).to have_css("#reader[data-reader-animation='slide']")

      watch_turns
      turn_page(:next)

      expect(page.evaluate_script("window.__turning")).to be(true)
    end

    it "turns pages instantly once switched off, on every device" do
      sign_in_and_wait_as(reader)
      open_reader(pdf)

      click_button "Reading settings"
      uncheck "Animate page turns"
      expect(page).to have_css("#reader[data-reader-animation='none']")
      expect(reader.reload.reader_page_animation).to be(false)

      watch_turns
      turn_page(:next)
      expect(page.evaluate_script("window.__turning")).to be(false)
      expect(page.evaluate_script("window.__changedAfter")).to be < 100

      Capybara.reset_session!
      sign_in_and_wait_as(reader)
      open_reader(pdf)
      expect(page).to have_css("#reader[data-reader-animation='none']")
    end

    it "slides the other way for a right-to-left book" do
      manga = create(:book, :published, :manga, file_fixture_name: "reader/manga-rtl-4-pages.cbz")
      sign_in_and_wait_as(reader)

      open_reader(pdf)
      watch_turns
      turn_page(:next)
      expect(last_slide_end).to be < 0

      open_reader(manga)
      watch_turns
      turn_page(:next)
      expect(last_slide_end).to be > 0
    end

    it "lands three quick turns exactly three pages ahead" do
      sign_in_and_wait_as(reader)
      open_reader(pdf)

      3.times { press_reader_key(:page_down) }

      expect(page).to have_css("#reader[data-reader-location='4']")
      expect(page).to have_no_css("#reader[data-reader-turning]")
    end

    it "turns instantly when the device asks to reduce motion" do
      emulate_reduced_motion
      sign_in_and_wait_as(reader)
      open_reader(pdf)

      expect(page).to have_css("#reader[data-reader-animation='none']")
      expect(reader.reader_page_animation).to be(true)
    end

    it "opens Reading settings from the account menu" do
      sign_in_and_wait_as(reader)

      click_button "Account menu"
      click_link "Reading settings"
      within("dialog.modal") { uncheck "Animate page turns" }

      expect { reader.reload.reader_page_animation }.to eventually(be(false))
      click_button "Done"
      expect(page).to have_no_css("dialog.modal[open]")
    end
  end
end
