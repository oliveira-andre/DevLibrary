require "rails_helper"

RSpec.describe ReadingPosition, type: :model do
  let(:user) { create(:user) }
  let(:book) { create(:book, :published) }
  let(:now) { Time.zone.local(2026, 10, 14, 10, 5, 0) }

  before { travel_to(now) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:book) }

  def record(**attributes)
    ReadingPosition.record!(user: user, book: book, location: "42", progress: 30, read_at: now, **attributes)
  end

  describe ".record!" do
    it "creates the position on the first page turn" do
      position = record

      expect(position).to have_attributes(location: "42", progress: 30)
      expect(position.read_at).to be_within(1.second).of(now)
    end

    it "ignores an update stamped earlier than the saved one" do
      record
      record(location: "38", progress: 25, read_at: now - 4.minutes)

      expect(ReadingPosition.find_by(user: user, book: book).location).to eq("42")
    end

    it "applies a newer update" do
      record
      record(location: "50", progress: 40, read_at: now + 30.seconds)

      expect(ReadingPosition.find_by(user: user, book: book).location).to eq("50")
    end

    it "clamps a device time far in the future to now" do
      position = record(read_at: now + 2.hours)

      expect(position.read_at).to be_within(1.second).of(now)
    end

    it "keeps a single row per reader and book" do
      record
      record(location: "43", read_at: now + 1.second)

      expect(ReadingPosition.where(user: user, book: book).count).to eq(1)
    end

    it "works for a book that is not in the reader's library" do
      expect(user.library.books).not_to include(book)

      expect { record }.to change(ReadingPosition, :count).by(1)
    end

    it "survives removing the book from the library" do
      user.library.add!(book)
      record

      user.library.remove!(book)

      expect(ReadingPosition.where(user: user, book: book)).to exist
    end

    it "touches the reader but not the book" do
      user
      book
      travel_to(now + 1.minute) do
        expect { record(read_at: now + 1.minute) }
          .to change { user.reload.updated_at }
          .and(not_change { book.reload.updated_at })
      end
    end
  end

  it "rejects progress outside 0..100" do
    expect(build(:reading_position, progress: 101)).not_to be_valid
    expect(build(:reading_position, progress: -1)).not_to be_valid
  end

  describe "reading direction override" do
    let(:book) { create(:book, :published, :manga) }

    it "uses the book's direction until the reader chooses one" do
      expect(record.effective_reading_direction).to eq("rtl")
    end

    it "applies the reader's own choice for that book only" do
      ReadingPosition.set_direction!(user: user, book: book, direction: "ltr")

      expect(ReadingPosition.find_by(user: user, book: book).effective_reading_direction).to eq("ltr")
      expect(book.reload.reading_direction).to eq("rtl")
    end

    it "can be cleared back to the book's direction" do
      ReadingPosition.set_direction!(user: user, book: book, direction: "ltr")
      ReadingPosition.set_direction!(user: user, book: book, direction: nil)

      expect(ReadingPosition.find_by(user: user, book: book).effective_reading_direction).to eq("rtl")
    end

    it "rejects an unknown direction" do
      expect(build(:reading_position, reading_direction: "up")).not_to be_valid
    end
  end

  describe ".for", :caching do
    it "serves a repeat lookup without touching the database" do
      record
      ReadingPosition.for(user: user, book: book)

      expect(count_queries { ReadingPosition.for(user: user, book: book) }).to eq(0)
    end

    it "reflects a newer position right away" do
      record
      ReadingPosition.for(user: user, book: book)

      travel_to(now + 1.minute) { record(location: "60", read_at: now + 1.minute) }

      expect(ReadingPosition.for(user: user, book: book).location).to eq("60")
    end
  end
end
