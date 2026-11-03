require "rails_helper"

RSpec.describe "Home: your collection", type: :request do
  let(:reader) { create(:user) }
  let(:library) { reader.library }

  def collection_titles
    response.parsed_body.css("#collection .collection__item .collection__title").map(&:text)
  end

  it "is not shown when the collection is empty" do
    create(:book, :published)
    sign_in_as(reader)

    get home_path

    expect(response.parsed_body.at_css("#collection")).to be_nil
    expect(response.body).not_to include("Your collection")
  end

  context "with books in the collection" do
    let!(:yesterday) { create(:book, :published, title: "Read Yesterday") }
    let!(:recent) { create(:book, :published, title: "Read An Hour Ago") }
    let!(:unread) { create(:book, :published, title: "Never Opened") }

    before do
      travel_to(2.days.ago) { library.add!(yesterday) }
      travel_to(1.day.ago) { library.add!(recent) }
      library.add!(unread)
      ReadingPosition.record!(user: reader, book: yesterday, location: "12", progress: 30, read_at: 1.day.ago)
      ReadingPosition.record!(user: reader, book: recent, location: "42", progress: 87.5, read_at: 1.hour.ago)
      sign_in_as(reader)
    end

    it "shows the row above the newest books" do
      get home_path

      headings = response.parsed_body.css("h2").map { |h| h.text.strip }
      expect(headings.index("Your collection")).to be < headings.index("Newest books")
    end

    it "orders books by most recently read, then most recently added" do
      get home_path

      expect(collection_titles).to eq([ "Read An Hour Ago", "Read Yesterday", "Never Opened" ])
    end

    it "opens each book straight in the reader" do
      get home_path

      item = response.parsed_body.at_css("#collection .collection__item")
      expect(item["href"]).to eq(book_reader_path(recent))
    end

    it "shows how far each book has been read" do
      get home_path

      bar = response.parsed_body.at_css("#collection .collection__item [role='progressbar']")
      expect(bar["aria-valuenow"]).to eq("88")
      expect(bar["aria-label"]).to eq("88% read")
    end

    it "still shows a book the admins archived" do
      recent.archive!

      get home_path

      expect(collection_titles).to include("Read An Hour Ago")
    end

    it "never shows another person's collection" do
      other = create(:user)
      other.library.add!(create(:book, :published, title: "Someone Else's"))

      get home_path

      expect(collection_titles).not_to include("Someone Else's")
    end
  end
end
