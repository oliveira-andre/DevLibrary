require "rails_helper"

RSpec.describe Book, type: :model do
  it { is_expected.to have_many(:categorizations).dependent(:destroy) }
  it { is_expected.to have_many(:categories).through(:categorizations) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_length_of(:title).is_at_most(255) }

  describe "defaults" do
    subject(:book) { create(:book) }

    it { expect(Book.new.authors).to eq([]) }
    it { expect(book.kind).to eq("book") }
    it { expect(book.status).to eq("draft") }
    it { expect(book).to be_kind_book }
  end

  it "rejects an unknown kind with a validation error" do
    book = build(:book, kind: "magazine")

    expect(book).not_to be_valid
    expect(book.errors[:kind]).to include("is not included in the list")
  end

  describe "reading direction" do
    it "defaults to right-to-left for a new manga" do
      expect(create(:book, kind: "manga").reading_direction).to eq("rtl")
    end

    it "defaults to left-to-right for a new comic" do
      expect(create(:book, kind: "comic").reading_direction).to eq("ltr")
    end

    it "lets an admin choose left-to-right for a manga" do
      expect(create(:book, kind: "manga", reading_direction: "ltr").reading_direction).to eq("ltr")
    end

    it "follows a kind change when the direction was not changed with it" do
      book = create(:book, kind: "book")

      book.update!(kind: "manga")

      expect(book.reading_direction).to eq("rtl")
    end

    it "keeps a direction changed in the same save as the kind" do
      book = create(:book, kind: "book")

      book.update!(kind: "comic", reading_direction: "rtl")

      expect(book.reading_direction).to eq("rtl")
    end
  end

  describe "status lifecycle" do
    it "refuses to publish without a book file" do
      book = create(:book)

      expect { book.publish! }.to raise_error(ActiveRecord::RecordInvalid, /File is required to publish/)
    end

    it "sets published_at only on the first publish" do
      book = create(:book, :with_file)
      first = Time.zone.local(2026, 10, 14, 9, 0, 0)

      travel_to(first) { book.publish! }
      travel_to(first + 1.day) { book.archive! }
      travel_to(first + 2.days) { book.publish! }

      expect(book.reload.published_at).to be_within(1.second).of(first)
    end

    it "can be unpublished back to draft" do
      book = create(:book, :published)

      book.unpublish!

      expect(book).to be_draft
    end
  end

  describe "public id" do
    it "is 12 base58 characters" do
      expect(create(:book).public_id).to match(/\A[1-9A-HJ-NP-Za-km-z]{12}\z/)
    end

    it "never changes when the title changes" do
      book = create(:book)

      expect { book.update!(title: "Another title") }.not_to change { book.reload.public_id }
    end

    it "is the route parameter" do
      book = create(:book)

      expect(book.to_param).to eq(book.public_id)
    end
  end

  it "stores normalized search text from the title and authors" do
    book = create(:book, title: "Café Noir", authors: [ "José Saramago" ])

    expect(book.search_text).to eq("cafe noir jose saramago")
  end

  it "keeps emoji in the rich-text description" do
    book = create(:book, description: "Great 🤯 👨‍👩‍👧 🇧🇷")

    expect(book.reload.description.to_plain_text).to eq("Great 🤯 👨‍👩‍👧 🇧🇷")
  end

  describe ".visible_to" do
    let!(:draft) { create(:book) }
    let!(:published) { create(:book, :published) }
    let!(:archived) { create(:book, :archived) }

    it "shows admins every book" do
      expect(Book.visible_to(create(:user, :admin))).to contain_exactly(draft, published, archived)
    end

    it "shows readers published books only" do
      expect(Book.visible_to(create(:user))).to contain_exactly(published)
    end

    it "also shows a reader the archived books already in their library" do
      reader = create(:user)
      archived.update!(status: "published")
      reader.library.add!(archived)
      archived.archive!

      expect(Book.visible_to(reader)).to contain_exactly(published, archived)
      expect(Book.visible_to(create(:user))).to contain_exactly(published)
    end
  end

  describe ".find_visible! (share links)" do
    let(:reader) { create(:user) }

    it "finds a published book by its public id" do
      book = create(:book, :published)

      expect(Book.find_visible!(book.public_id, user: reader)).to eq(book)
    end

    it "does not find a draft for a reader" do
      draft = create(:book)

      expect { Book.find_visible!(draft.public_id, user: reader) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "finds a draft for an admin" do
      draft = create(:book)

      expect(Book.find_visible!(draft.public_id, user: create(:user, :admin))).to eq(draft)
    end

    it "does not find a deleted book" do
      book = create(:book, :published)
      public_id = book.public_id
      book.destroy!

      expect { Book.find_visible!(public_id, user: reader) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "finds an archived book only for readers who keep it in their library" do
      book = create(:book, :published)
      reader.library.add!(book)
      book.archive!

      expect(Book.find_visible!(book.public_id, user: reader)).to eq(book)
      expect { Book.find_visible!(book.public_id, user: create(:user)) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "shares only the book's own identifier, nothing about the sharer's library" do
      book = create(:book, :published)
      reader.library.favorite!(book)

      expect(book.to_param).to eq(book.public_id)
      expect(book.to_param).not_to include(reader.library.id.to_s, reader.id.to_s)
    end
  end

  describe ".catalog_version" do
    it "changes when a book is created, updated or destroyed" do
      book = create(:book)
      versions = [ Book.catalog_version ]

      travel(1.minute) { book.update!(title: "Changed") }
      versions << Book.catalog_version
      create(:book)
      versions << Book.catalog_version
      book.destroy!
      versions << Book.catalog_version

      expect(versions.uniq.size).to eq(4)
    end
  end

  describe "cover variants" do
    it "defines the card and large sizes, generated when the cover is attached" do
      variants = Book.attachment_reflections["cover"].named_variants

      expect(variants.keys).to include(:card, :large)
      expect(variants[:card].transformations).to include(resize_to_fill: [ 480, 720 ], format: :webp)
      expect(variants[:large].transformations).to include(resize_to_limit: [ 600, 900 ], format: :webp)
      expect(variants.values_at(:card, :large)).to all(be_preprocessed(nil))
    end
  end

  describe ".find_visible_cached!" do
    let(:reader) { create(:user) }

    it "finds a published book by its public id" do
      book = create(:book, :published)

      expect(Book.find_visible_cached!(book.public_id, user: reader)).to eq(book)
    end

    it "raises for drafts and unknown ids" do
      draft = create(:book)

      expect { Book.find_visible_cached!(draft.public_id, user: reader) }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Book.find_visible_cached!("nope", user: reader) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "finds an archived book only for readers who keep it" do
      book = create(:book, :published)
      reader.library.add!(book)
      book.archive!

      expect(Book.find_visible_cached!(book.public_id, user: reader.reload)).to eq(book)
      expect { Book.find_visible_cached!(book.public_id, user: create(:user)) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context "with caching", :caching do
      let(:book) { create(:book, :published, :with_cover) }

      it "serves a repeat lookup with only the catalog version query" do
        Book.find_visible_cached!(book.public_id, user: reader)

        expect(count_queries { Book.find_visible_cached!(book.public_id, user: reader) }).to eq(1)
      end

      it "comes back with what the book page needs already loaded" do
        found = Book.find_visible_cached!(book.public_id, user: reader)

        expect(found.association(:cover_attachment)).to be_loaded
        expect(found.association(:categories)).to be_loaded
        expect(found.association(:rich_text_description)).to be_loaded
      end

      it "reflects a change to the book" do
        Book.find_visible_cached!(book.public_id, user: reader)
        travel(1.minute) { book.update!(title: "Renamed") }

        expect(Book.find_visible_cached!(book.public_id, user: reader).title).to eq("Renamed")
      end

      it "stops finding an archived book once the reader removes it from their library" do
        reader.library.add!(book)
        book.archive!
        Book.find_visible_cached!(book.public_id, user: reader.reload)

        travel(1.minute) { reader.library.remove!(book) }

        expect { Book.find_visible_cached!(book.public_id, user: reader.reload) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  it "destroys its categorizations with it" do
    book = create(:book, categories: [ create(:category) ])

    expect { book.destroy! }.to change(Categorization, :count).by(-1)
  end

  it "removes everything that belongs to it when deleted (FR-022)" do
    book = create(:book, :published, :epub, :with_cover, categories: [ create(:category) ])
    reader = create(:user)
    reader.library.favorite!(book)
    ReadingPosition.record!(user: reader, book: book, location: "3", progress: 10, read_at: Time.current)
    reader.bookmarks.create!(book: book, location: "3", progress: 10)
    reader.notes.create!(book: book, location: "3", progress: 10, content: "note")
    book.reviews.create!(user: reader, rating: 5, content: "great")
    Conversion.request!(book: book, target_format: "pdf", user: reader)

    book.destroy!

    [ Categorization, LibraryEntry, ShelfPlacement, ReadingPosition, Bookmark, Note, Review, Conversion ].each do |model|
      expect(model.count).to eq(0), "expected no #{model.name} rows left"
    end
    expect(reader.library.favorites_shelf.reload).to be_persisted
  end
end
