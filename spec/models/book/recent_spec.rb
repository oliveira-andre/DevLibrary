require "rails_helper"

RSpec.describe Book::Recent, type: :model do
  let(:noon) { Time.zone.local(2026, 10, 20, 12) }

  it "lists published books newest first" do
    books = insert_published_books(3, newest_at: noon)

    expect(Book.recent.books).to eq(books.reverse)
  end

  it "breaks ties on the same publish time by id, newest id first" do
    first, second = 2.times.map { create(:book, :published) }
    Book.where(id: [ first.id, second.id ]).update_all(published_at: noon)

    expect(Book.recent.books).to eq([ second, first ])
    expect(Book.recent(per: 1).then { |page| Book.recent(before: page.next_params[:before], per: 1).books }).to eq([ first ])
  end

  it "returns 50 books and a cursor for the next batch when more exist" do
    books = insert_published_books(52, newest_at: noon)

    page = Book.recent

    expect(page.books).to eq(books.reverse.first(50))
    expect(page.next_params).to match(before: a_kind_of(String))
  end

  it "returns the rest and no cursor on the last batch" do
    books = insert_published_books(52, newest_at: noon)

    last = Book.recent(before: Book.recent.next_params[:before])

    expect(last.books).to eq(books.first(2).reverse)
    expect(last.next_params).to be_nil
  end

  it "has no next batch with exactly 50 books" do
    insert_published_books(50, newest_at: noon)

    expect(Book.recent.next_params).to be_nil
  end

  it "never lists drafts or archived books" do
    published = create(:book, :published)
    create(:book)
    create(:book, :archived)

    expect(Book.recent.books).to eq([ published ])
  end

  it "treats a malformed or tampered cursor as the first batch" do
    books = insert_published_books(3, newest_at: noon)

    [ "garbage", "!!", Base64.urlsafe_encode64("not-a-time|x"), "" ].each do |cursor|
      expect(Book.recent(before: cursor).books).to eq(books.reverse)
    end
  end

  it "never repeats or skips a book when one is published between batches" do
    books = insert_published_books(55, newest_at: noon)
    first = Book.recent

    newcomer = travel_to(noon + 1.hour) { create(:book, :published) }
    second = Book.recent(before: first.next_params[:before])

    shown = first.books + second.books
    expect(shown).to eq(books.reverse)
    expect(shown).not_to include(newcomer)
  end

  it "comes with covers preloaded" do
    create(:book, :published, :with_cover)

    expect(Book.recent.books.first.association(:cover_attachment)).to be_loaded
  end

  context "with caching", :caching do
    it "serves a repeat batch with only the catalog version query" do
      insert_published_books(3, newest_at: noon)
      Book.recent

      expect(count_queries { Book.recent }).to eq(1)
    end

    it "reflects a newly published book" do
      Book.recent
      book = create(:book, :published)

      expect(Book.recent.books).to include(book)
    end
  end
end
