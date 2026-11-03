require "rails_helper"

RSpec.describe "Home", type: :request do
  it "sends signed-out visitors to sign-in" do
    get home_path

    expect(response).to redirect_to(new_session_path)
  end

  it "sends signed-out visitors at the root to sign-in" do
    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "is where sign-in lands by default" do
    sign_in_as(create(:user))

    expect(response).to redirect_to(home_url)
  end

  context "when signed in" do
    before { sign_in_as(create(:user)) }

    def recent_card_ids
      response.parsed_body.css("#recent_books .book-card").map { |card| card["id"] }
    end

    it "lists the 50 most recently published books, newest first" do
      books = insert_published_books(51)

      get home_path

      expect(response).to have_http_status(:ok)
      expect(recent_card_ids).to eq(books.reverse.first(50).map { |book| "book_#{book.id}" })
    end

    it "offers See more when more books exist" do
      insert_published_books(51)

      get home_path

      link = response.parsed_body.at_css("#recent_books_more a")
      expect(link.text).to eq("See more")
      expect(link["href"]).to start_with("/recent_books?before=")
      expect(link["data-turbo-stream"]).to eq("true")
    end

    it "has no See more with exactly 50 books" do
      insert_published_books(50)

      get home_path

      expect(response.parsed_body.at_css("#recent_books_more a")).to be_nil
    end

    it "gives every card its cover, title and a Read action" do
      book = create(:book, :published, title: "Café Noir")

      get home_path

      card = response.parsed_body.at_css("#book_#{book.id}")
      expect(card.at_css("a.book-card__title").text).to eq("Café Noir")
      expect(card.at_css(".cover-placeholder")).to be_present
      expect(card.at_css("a[href='#{book_reader_path(book)}']")).to be_present
    end

    it "shows a friendly message when nothing is published yet" do
      create(:book)

      get home_path

      expect(response.body).to include("No books yet")
      expect(response.parsed_body.at_css("#recent_books")).to be_nil
    end
  end
end
