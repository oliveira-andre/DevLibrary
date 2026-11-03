require "rails_helper"

RSpec.describe "Switching the reading direction", type: :request do
  let(:reader) { create(:user) }
  let(:manga) { create(:book, :published, :manga) }

  before { sign_in_as(reader) }

  def streamed_preferences
    turbo_stream_for("replace", "reader_preferences").at_css("template #reader_preferences")
  end

  it "saves the reader's own direction for this book and updates the reader" do
    patch book_reading_direction_path(manga), params: { direction: "ltr" }, as: :turbo_stream

    expect(response).to have_http_status(:ok)
    expect(ReadingPosition.find_by!(user: reader, book: manga).reading_direction).to eq("ltr")
    expect(streamed_preferences["data-reader-preferences-direction-value"]).to eq("ltr")
    expect(turbo_stream_for("replace", "reader_direction_form")).to be_present
  end

  it "goes back to the book's direction when cleared" do
    ReadingPosition.set_direction!(user: reader, book: manga, direction: "ltr")

    patch book_reading_direction_path(manga), params: { direction: "" }, as: :turbo_stream

    expect(ReadingPosition.find_by!(user: reader, book: manga).reading_direction).to be_nil
    expect(streamed_preferences["data-reader-preferences-direction-value"]).to eq("rtl")
  end

  it "only changes it for this reader" do
    other = create(:user)

    patch book_reading_direction_path(manga), params: { direction: "ltr" }, as: :turbo_stream

    expect(ReadingPosition.find_by(user: other, book: manga)).to be_nil
  end

  it "rejects an unknown direction" do
    patch book_reading_direction_path(manga), params: { direction: "up" }, as: :turbo_stream

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "sends signed-out visitors to sign-in" do
    delete session_path
    patch book_reading_direction_path(manga), params: { direction: "ltr" }

    expect(response).to redirect_to(new_session_path)
  end
end
