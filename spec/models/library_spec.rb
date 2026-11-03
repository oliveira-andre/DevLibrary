require "rails_helper"

RSpec.describe Library, type: :model do
  let(:user) { create(:user) }
  let(:library) { user.library }
  let(:book) { create(:book, :published) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:entries).dependent(:destroy) }
  it { is_expected.to have_many(:shelves).dependent(:destroy) }

  it "is created with the account, holding only the Favorites shelf" do
    expect(library).to be_persisted
    expect(library.shelves.map(&:name)).to eq([ "Favorites" ])
    expect(library.favorites_shelf).to be_kind_favorites
  end

  describe "#add!" do
    it "adds a published book once, however often it is called" do
      2.times { library.add!(book) }

      expect(library.entries.where(book: book).count).to eq(1)
    end

    it "refuses a draft book" do
      expect { library.add!(create(:book)) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "favorites" do
    it "adds the book to the library and to Favorites" do
      library.favorite!(book)

      expect(library.books).to include(book)
      expect(library).to be_favorited(book)
    end

    it "removes the book from Favorites only when unfavorited" do
      library.favorite!(book)

      library.unfavorite!(book)

      expect(library).not_to be_favorited(book)
      expect(library.books).to include(book)
    end
  end

  describe "shelves" do
    let(:manga) { library.shelves.create!(name: "Manga") }
    let(:to_read) { library.shelves.create!(name: "To read") }

    it "places a book on several shelves, adding it to the library when needed" do
      library.place!(book, shelf: manga)
      library.place!(book, shelf: to_read)

      expect(manga.entries.map(&:book)).to eq([ book ])
      expect(to_read.entries.map(&:book)).to eq([ book ])
      expect(library.entries.count).to eq(1)
    end

    it "takes a book off one shelf" do
      library.place!(book, shelf: manga)
      library.place!(book, shelf: to_read)

      library.unplace!(book, shelf: manga)

      expect(manga.entries).to be_empty
      expect(to_read.entries.map(&:book)).to eq([ book ])
    end
  end

  describe "#remove!" do
    it "removes the entry and every shelf placement but keeps the catalog book" do
      shelf = library.shelves.create!(name: "Manga")
      library.favorite!(book)
      library.place!(book, shelf: shelf)

      library.remove!(book)

      expect(library.entries).to be_empty
      expect(ShelfPlacement.count).to eq(0)
      expect(Book.exists?(book.id)).to be(true)
    end

    it "keeps the reader's position, bookmarks and notes for the book" do
      library.add!(book)
      ReadingPosition.record!(user: user, book: book, location: "12", progress: 40, read_at: Time.current)
      user.bookmarks.create!(book: book, location: "12", progress: 40)
      user.notes.create!(book: book, location: "12", progress: 40, content: "Keep me 📌")

      library.remove!(book)

      expect(ReadingPosition.where(user: user, book: book)).to exist
      expect(user.bookmarks.where(book: book)).to exist
      expect(user.notes.where(book: book)).to exist
    end
  end

  describe "#search" do
    let!(:cafe) { create(:book, :published, title: "Café Noir") }
    let!(:other) { create(:book, :published, title: "Other Story") }

    before do
      library.add!(cafe)
      library.add!(other)
      create(:user).library.add!(create(:book, :published, title: "Café Society"))
    end

    it "returns only this reader's entries that match, ignoring accents" do
      expect(library.search(query: "cafe").map(&:book)).to eq([ cafe ])
    end

    it "filters by shelf" do
      shelf = library.shelves.create!(name: "Noir")
      library.place!(cafe, shelf: shelf)

      expect(library.search(shelf: shelf).map(&:book)).to eq([ cafe ])
    end

    it "lists the most recently added first when nothing has been read" do
      later = create(:book, :published)
      travel(1.minute) { library.add!(later) }

      expect(library.search.map(&:book).first).to eq(later)
    end

    it "lists the most recently read first and carries the saved position" do
      ReadingPosition.record!(user: user, book: cafe, location: "7", progress: 64.5, read_at: 1.minute.from_now)

      entries = user.reload.library.search

      expect(entries.first.book).to eq(cafe)
      expect(entries.first.reading_location).to eq("7")
      expect(entries.first.reading_progress).to eq(64.5)
      expect(entries.last.reading_location).to be_nil
    end

    context "with caching", :caching do
      it "serves a repeat search with only the catalog version query" do
        library.search(query: "cafe")

        expect(count_queries { library.search(query: "cafe") }).to eq(1)
      end

      it "reflects a newly added book" do
        library.search
        newcomer = create(:book, :published)
        library.add!(newcomer)

        expect(user.reload.library.search.map(&:book)).to include(newcomer)
      end

      it "reflects a new shelf placement" do
        shelf = library.shelves.create!(name: "Noir")
        library.search(shelf: shelf)
        library.place!(cafe, shelf: shelf)

        expect(user.reload.library.search(shelf: shelf).map(&:book)).to eq([ cafe ])
      end

      it "reflects a renamed book" do
        library.search(query: "cafe")
        travel(1.minute) { cafe.update!(title: "Totally Different") }

        expect(user.reload.library.search(query: "cafe")).to be_empty
      end
    end
  end
end
