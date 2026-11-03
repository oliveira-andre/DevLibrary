require "rails_helper"

RSpec.describe "Home: your collection", type: :system do
  on_each_viewport do
    let(:reader) { create(:user) }
    let(:books) { Array.new(12) { |i| create(:book, :published, title: format("Shelf Book %02d", i + 1)) } }

    before do
      books.each_with_index do |book, i|
        reader.library.add!(book)
        ReadingPosition.record!(user: reader, book: book, location: "1", progress: 10, read_at: (i + 1).minutes.ago)
      end
    end

    def row_scroll_left
      page.evaluate_script("document.getElementById('collection').scrollLeft")
    end

    it "shows the collection above the newest books, most recently read first" do
      sign_in_and_wait_as(reader)

      within("#collection") do
        expect(first(".collection__title")).to have_text("Shelf Book 01")
      end
      collection_top = page.evaluate_script("document.getElementById('collection').getBoundingClientRect().top")
      newest_top = page.evaluate_script("document.getElementById('recent_books').getBoundingClientRect().top")
      expect(collection_top).to be < newest_top
    end

    it "scrolls sideways through the whole collection without moving the page" do
      sign_in_and_wait_as(reader)
      expect(page).to have_css("#collection .collection__item", count: 12)
      page_scroll_before = page.evaluate_script("window.scrollY")

      if mobile_viewport?
        rect = page.evaluate_script("document.getElementById('collection').getBoundingClientRect().toJSON()")
        y = rect["top"] + rect["height"] / 3
        touch_swipe(from: [ rect["left"] + rect["width"] * 0.9, y ], to: [ rect["left"] + rect["width"] * 0.1, y ])
      else
        click_button "Scroll collection forward"
      end

      expect { row_scroll_left }.to eventually(be > 0)
      expect(page.evaluate_script("window.scrollY")).to eq(page_scroll_before)
    end

    it "links each book straight to the reader" do
      sign_in_and_wait_as(reader)

      expect(first("#collection .collection__item")[:href]).to end_with(book_reader_path(books.first))
    end
  end
end
