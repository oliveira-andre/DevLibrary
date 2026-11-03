require "rails_helper"

RSpec.describe "Saving the reading position", type: :request do
  let(:reader) { create(:user) }
  let(:book) { create(:book, :published) }

  before { sign_in_as(reader) }

  def save_position(location:, progress:, read_at:, target: book)
    patch book_reading_position_path(target), params: { location: location, progress: progress, read_at: read_at }, as: :json
  end

  it "stores the position and answers 204" do
    save_position(location: "12", progress: 25.5, read_at: "2026-10-20T13:00:00Z")

    expect(response).to have_http_status(:no_content)
    position = ReadingPosition.find_by!(user: reader, book: book)
    expect(position).to have_attributes(location: "12", progress: 25.5)
    expect(position.read_at).to eq(Time.zone.parse("2026-10-20 13:00:00 UTC"))
  end

  it "keeps the newest position when an older save arrives late" do
    save_position(location: "14", progress: 30, read_at: "2026-10-20T13:05:00Z")
    save_position(location: "10", progress: 20, read_at: "2026-10-20T13:01:00Z")

    expect(response).to have_http_status(:no_content)
    expect(ReadingPosition.find_by!(user: reader, book: book).location).to eq("14")
  end

  it "does not add the book to the reader's collection" do
    save_position(location: "2", progress: 5, read_at: "2026-10-20T13:00:00Z")

    expect(reader.library.books).to be_empty
  end

  it "rejects an impossible progress with the reason" do
    save_position(location: "2", progress: 150, read_at: "2026-10-20T13:00:00Z")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"]).to be_present
  end

  it "answers 404 for a book the reader can't see" do
    save_position(location: "1", progress: 0, read_at: "2026-10-20T13:00:00Z", target: create(:book, :with_file))

    expect(response).to have_http_status(:not_found)
  end

  it "answers 401, not a redirect, when the session has ended" do
    delete session_path
    save_position(location: "3", progress: 10, read_at: "2026-10-20T13:00:00Z")

    expect(response).to have_http_status(:unauthorized)
    expect(ReadingPosition.where(book: book)).to be_empty
  end
end
