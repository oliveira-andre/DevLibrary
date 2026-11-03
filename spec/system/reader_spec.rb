require "rails_helper"

RSpec.describe "Reader", type: :system do
  on_each_viewport do
    let(:reader) { create(:user) }

    def publish(fixture, **attributes)
      create(:book, :published, file_fixture_name: fixture, **attributes)
    end

    def saved_location(book)
      ReadingPosition.find_by(user: reader, book: book)&.location
    end

    def open_reader(book)
      visit book_reader_path(book)
      wait_for_reader
    end

    {
      "a PDF" => [ "reader/text-6-pages.pdf", {} ],
      "an EPUB" => [ "reader/reflowable-3-chapters.epub", {} ],
      "a comic" => [ "reader/comic-4-pages.cbz", {} ],
      "a right-to-left manga" => [ "reader/manga-rtl-4-pages.cbz", { kind: "manga" } ]
    }.each do |name, (fixture, attributes)|
      it "reopens #{name} where the reader stopped, in a fresh session" do
        book = publish(fixture, **attributes)
        sign_in_and_wait_as(reader)
        open_reader(book)

        start = reader_location
        3.times { turn_page(:next) }
        stopped = reader_location
        expect(stopped).not_to eq(start)
        expect { saved_location(book) }.to eventually(eq(stopped))

        Capybara.reset_session!
        sign_in_and_wait_as(reader)
        open_reader(book)

        expect(page).to have_css("#reader[data-reader-location=\"#{stopped}\"]")
      end
    end

    it "opens any book from its card with one tap" do
      book = publish("reader/text-6-pages.pdf", title: "One Tap")
      sign_in_and_wait_as(reader)

      click_link "Read One Tap"

      wait_for_reader
      expect(page).to have_current_path(book_reader_path(book))
      expect(reader_location).to eq("1")
    end

    it "turns a right-to-left manga forward with the left edge and ArrowLeft" do
      manga = publish("reader/manga-rtl-4-pages.cbz", kind: "manga")
      sign_in_and_wait_as(reader)
      open_reader(manga)

      tap_reader_edge(:left)
      expect(page).to have_css("#reader[data-reader-location='2']")

      press_reader_key(:arrow_left)
      expect(page).to have_css("#reader[data-reader-location='3']")

      press_reader_key(:arrow_right)
      expect(page).to have_css("#reader[data-reader-location='2']")
    end

    it "lets the reader switch the direction for this book, and remembers it" do
      manga = publish("reader/manga-rtl-4-pages.cbz", kind: "manga")
      sign_in_and_wait_as(reader)
      open_reader(manga)

      click_button "Switch to left-to-right"
      expect(page).to have_css("#reader_preferences[data-reader-preferences-direction-value='ltr']", visible: :all)
      press_reader_key(:arrow_right)
      expect(page).to have_css("#reader[data-reader-location='2']")

      open_reader(manga)
      expect(page).to have_css("#reader_preferences[data-reader-preferences-direction-value='ltr']", visible: :all)
      expect(ReadingPosition.find_by!(user: reader, book: manga).reading_direction).to eq("ltr")
    end

    it "reflows an EPUB to larger text and the dark theme, staying in the same chapter" do
      book = publish("reader/reflowable-3-chapters.epub")
      sign_in_and_wait_as(reader)
      open_reader(book)
      turn_page(:next)
      chapter = find("#reader [data-reader-target='label']").text

      click_button "Reading settings"
      choose "Dark"
      expect(page).to have_css("#reader[data-reader-theme='dark']")
      click_button "Larger text"
      expect(page).to have_css("#reader_preferences[data-reader-preferences-text-size-value='115']", visible: :all)

      expect(page).to have_css("#reader [data-reader-target='label']", text: chapter)
      expect(reader.reload.reading_settings).to include(theme: "dark", text_size: 115)
    end

    it "zooms a comic page and pauses page turns until it fits again" do
      comic = publish("reader/comic-4-pages.cbz")
      sign_in_and_wait_as(reader)
      open_reader(comic)

      mobile_viewport? ? pinch_reader : click_button("Zoom in")
      expect(page).to have_css("#reader[data-reader-zoomed='true']")

      press_reader_key(:page_down)
      sleep 0.4
      expect(reader_location).to eq("1")

      click_button "Fit page"
      expect(page).to have_css("#reader[data-reader-zoomed='false']")
      turn_page(:next)
      expect(reader_location).to eq("2")
    end

    it "stays on the last page and says the end has been reached" do
      pdf = publish("reader/text-6-pages.pdf")
      ReadingPosition.record!(user: reader, book: pdf, location: "6", progress: 100, read_at: 1.minute.ago)
      sign_in_and_wait_as(reader)
      open_reader(pdf)
      expect(reader_location).to eq("6")

      turn_page(:next, expect_change: false)

      expect(page).to have_text("You've reached the end")
      expect(reader_location).to eq("6")
    end

    it "says a CBR comic can't be opened yet and offers a way back" do
      cbr = publish("sample.cbr")
      sign_in_and_wait_as(reader)

      visit book_reader_path(cbr)

      expect(page).to have_text("This comic can't be opened in the reader yet")
      click_link "Back to home"
      expect(page).to have_current_path(home_path)
    end
  end
end
