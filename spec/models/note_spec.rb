require "rails_helper"

RSpec.describe Note, type: :model do
  let(:user) { create(:user) }
  let(:book) { create(:book, :published) }

  def note(content: "A thought", progress: 10, **attributes)
    user.notes.build(book: book, location: "15", progress: progress, content: content, **attributes)
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:book) }

  it "stores rich text with emoji intact" do
    saved = note(content: "Great twist 🤯").tap(&:save!)

    expect(saved.reload.content.to_plain_text).to eq("Great twist 🤯")
    expect(saved.location).to eq("15")
  end

  it "rejects empty or whitespace-only content" do
    expect(note(content: "")).not_to be_valid
    expect(note(content: "<div> </div>")).not_to be_valid
  end

  it "rejects more than 10,000 characters of text" do
    expect(note(content: "a" * 10_000)).to be_valid
    expect(note(content: "a" * 10_001)).not_to be_valid
  end

  it "requires a location and progress within 0..100" do
    expect(note(location: "")).not_to be_valid
    expect(note(progress: 101)).not_to be_valid
  end

  it "touches its author when the content is edited" do
    saved = note.tap(&:save!)

    travel 1.minute do
      expect { saved.update!(content: "Edited ✍️") }.to change { user.reload.updated_at }
    end
  end

  it "never changes the book itself (FR-042)" do
    book

    travel 1.minute do
      expect { note.save! }.not_to change { book.reload.attributes }
    end
  end

  it "is destroyed with its book" do
    note.save!

    expect { book.destroy! }.to change(Note, :count).by(-1)
  end

  describe ".for" do
    before do
      [ 30, 5, 12 ].each { |progress| note(progress: progress, content: "at #{progress}").save! }
      create(:user).notes.create!(book: book, location: "1", progress: 1, content: "not mine")
    end

    it "lists only the author's notes, in book order" do
      expect(Note.for(user: user, book: book).map(&:progress)).to eq([ 5, 12, 30 ])
    end

    context "with caching", :caching do
      it "serves a repeat lookup without touching the database" do
        Note.for(user: user, book: book)

        expect(count_queries { Note.for(user: user, book: book) }).to eq(0)
      end

      it "reflects an edited note" do
        Note.for(user: user, book: book)
        travel(1.minute) { user.notes.first.update!(content: "changed") }

        expect(Note.for(user: user.reload, book: book).map { |n| n.content.to_plain_text }).to include("changed")
      end
    end
  end
end
