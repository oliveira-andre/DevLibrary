require "rails_helper"

RSpec.describe "Reading settings", type: :request do
  let(:reader) { create(:user) }

  before { sign_in_as(reader) }

  def update_settings(settings, **extra)
    patch reading_settings_path, params: { reading_settings: settings, **extra }, as: :turbo_stream
  end

  it "saves the theme and text size on the account" do
    update_settings({ reader_theme: "dark", reader_text_size: "130" })

    expect(response).to have_http_status(:ok)
    expect(reader.reload.reading_settings).to include(theme: "dark", text_size: 130)
    expect(turbo_stream_for("replace", "reading_settings_form").text).to include("Saved")
  end

  it "also updates an open reader when sent from inside it" do
    book = create(:book, :published)

    update_settings({ reader_theme: "sepia" }, book_id: book.public_id)

    prefs = turbo_stream_for("replace", "reader_preferences").at_css("template #reader_preferences")
    expect(prefs["data-reader-preferences-theme-value"]).to eq("sepia")
  end

  it "rejects an unknown theme and keeps the old one" do
    update_settings({ reader_theme: "neon" })

    expect(response).to have_http_status(:unprocessable_content)
    expect(reader.reload.reader_theme).to eq("light")
  end

  it "only ever changes the signed-in reader's settings" do
    other = create(:user)

    update_settings({ reader_theme: "dark" }, user_id: other.id)

    expect(other.reload.reader_theme).to eq("light")
    expect(reader.reload.reader_theme).to eq("dark")
  end

  it "switches the page-turn animation off and back on" do
    update_settings({ reader_page_animation: "0" })
    expect(reader.reload.reader_page_animation).to be(false)

    update_settings({ reader_page_animation: "1" })
    expect(reader.reload.reader_page_animation).to be(true)
  end

  it "tells an open reader the new animation setting" do
    book = create(:book, :published)

    update_settings({ reader_page_animation: "0" }, book_id: book.public_id)

    prefs = turbo_stream_for("replace", "reader_preferences").at_css("template #reader_preferences")
    expect(prefs["data-reader-preferences-animation-value"]).to eq("false")
  end

  it "renders the settings form in the modal" do
    get edit_reading_settings_path

    expect(response).to have_http_status(:ok)
    form = response.parsed_body.at_css("turbo-frame#modal form#reading_settings_form")
    expect(form).to be_present
    expect(form.at_css("input[type=checkbox][role=switch][name='reading_settings[reader_page_animation]']")).to be_present
  end

  it "sends signed-out visitors to sign-in" do
    delete session_path
    patch reading_settings_path, params: { reading_settings: { reader_theme: "dark" } }

    expect(response).to redirect_to(new_session_path)
  end
end
