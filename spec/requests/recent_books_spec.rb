require "rails_helper"

RSpec.describe "Recent books (See more)", type: :request do
  let!(:books) { insert_published_books(120) }

  before { sign_in_as(create(:user)) }

  def appended_ids
    turbo_stream_for("append", "recent_books").css("template .book-card").map { |card| card["id"] }
  end

  it "appends the next 50 books and replaces the See more control" do
    get recent_books_path(Book.recent.next_params), as: :turbo_stream

    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(appended_ids).to eq(books.reverse[50, 50].map { |book| "book_#{book.id}" })
    expect(turbo_stream_for("replace", "recent_books_more").at_css("template a")["href"]).to start_with("/recent_books?before=")
  end

  it "empties the See more control on the last batch" do
    second = Book.recent(before: Book.recent.next_params[:before])
    get recent_books_path(second.next_params), as: :turbo_stream

    expect(appended_ids.size).to eq(20)
    control = turbo_stream_for("replace", "recent_books_more").at_css("template #recent_books_more")
    expect(control.at_css("a")).to be_nil
  end

  it "treats a bad cursor as the first batch" do
    get recent_books_path(before: "tampered"), as: :turbo_stream

    expect(appended_ids.first).to eq("book_#{books.last.id}")
  end

  it "renders a plain page of the batch for HTML requests" do
    get recent_books_path(Book.recent.next_params)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.css("#recent_books .book-card").size).to eq(50)
  end

  it "sends signed-out visitors to sign-in" do
    delete session_path
    get recent_books_path

    expect(response).to redirect_to(new_session_path)
  end
end
