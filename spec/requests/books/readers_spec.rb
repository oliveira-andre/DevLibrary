require "rails_helper"

RSpec.describe "Reader shell", type: :request do
  let(:reader) { create(:user) }
  let(:book) { create(:book, :published) }

  before { sign_in_as(reader) }

  def shell
    response.parsed_body.at_css("#reader")
  end

  def preferences
    response.parsed_body.at_css("#reader_preferences")
  end

  it "hands the browser the book's format and its endpoints" do
    get book_reader_path(book)

    expect(response).to have_http_status(:ok)
    expect(shell["data-controller"]).to eq("reader")
    expect(shell["data-reader-format-value"]).to eq("pdf")
    expect(shell["data-reader-file-url-value"]).to eq(book_file_path(book))
    expect(shell["data-reader-position-url-value"]).to eq(book_reading_position_path(book))
    expect(shell["data-reader-book-id-value"]).to eq(book.public_id)
    expect(shell["data-reader-user-id-value"]).to eq(reader.id.to_s)
    expect(shell["data-reader-state"]).to eq("loading")
  end

  it "starts at the beginning when the book was never opened" do
    get book_reader_path(book)

    expect(shell["data-reader-start-location-value"]).to eq("")
    expect(shell["data-reader-start-progress-value"]).to eq("0.0")
    expect(shell["data-reader-start-read-at-value"]).to eq("")
  end

  it "starts at the position saved on the reader's account" do
    ReadingPosition.record!(user: reader, book: book, location: "42", progress: 41.5,
                            read_at: Time.zone.parse("2026-10-20 13:05:00 UTC"))

    get book_reader_path(book)

    expect(shell["data-reader-start-location-value"]).to eq("42")
    expect(shell["data-reader-start-progress-value"]).to eq("41.5")
    expect(shell["data-reader-start-read-at-value"]).to eq("2026-10-20T13:05:00Z")
  end

  it "renders the reader's settings and the book's direction" do
    reader.update!(reader_theme: "sepia", reader_text_size: 130, reader_page_animation: false)
    manga = create(:book, :published, :manga)

    get book_reader_path(manga)

    expect(preferences["data-controller"]).to eq("reader-preferences")
    expect(preferences["data-reader-preferences-animation-value"]).to eq("false")
    expect(preferences["data-reader-preferences-theme-value"]).to eq("sepia")
    expect(preferences["data-reader-preferences-text-size-value"]).to eq("130")
    expect(preferences["data-reader-preferences-direction-value"]).to eq("rtl")
    expect(preferences["data-reader-preferences-direction-override-value"]).to eq("")
  end

  it "honors the reader's own direction for this book" do
    manga = create(:book, :published, :manga)
    ReadingPosition.set_direction!(user: reader, book: manga, direction: "ltr")

    get book_reader_path(manga)

    expect(preferences["data-reader-preferences-direction-value"]).to eq("ltr")
    expect(preferences["data-reader-preferences-direction-override-value"]).to eq("ltr")
  end

  it "says a CBR comic can't be opened in the reader yet, with a way back" do
    comic = create(:book, :published, file_fixture_name: "sample.cbr")

    get book_reader_path(comic)

    expect(shell["data-reader-state"]).to eq("unsupported")
    expect(response.body).to include("This comic can't be opened in the reader yet")
    expect(response.parsed_body.at_css("#reader a[href='#{home_path}']")).to be_present
  end

  it "shows the error state for a book without a file" do
    admin = create(:user, :admin)
    delete session_path
    sign_in_as(admin)

    get book_reader_path(create(:book, title: "No File Yet"))

    expect(shell["data-reader-state"]).to eq("error")
    expect(response.body).to include("This book can't be opened")
  end

  it "uses the reading layout: no nav bar, no logo, no decoration" do
    get book_reader_path(book)

    expect(response.parsed_body.at_css("body.reader")).to be_present
    expect(response.parsed_body.at_css(".nav")).to be_nil
    expect(response.body).not_to include("wordmark")
  end

  it "answers 404 for a draft" do
    get book_reader_path(create(:book))

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.text).to include("This book isn't available")
  end

  it "sends signed-out visitors to sign-in" do
    delete session_path
    get book_reader_path(book)

    expect(response).to redirect_to(new_session_path)
  end
end
