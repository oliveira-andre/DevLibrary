require "rails_helper"

RSpec.describe Bookmark, type: :model do
  let(:user) { create(:user) }
  let(:book) { create(:book, :published) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:book) }
  it { is_expected.to validate_presence_of(:location) }
  it { is_expected.to validate_length_of(:label).is_at_most(100) }

  it "allows only one bookmark per position" do
    user.bookmarks.create!(book: book, location: "10", progress: 10)

    expect(user.bookmarks.build(book: book, location: "10", progress: 10)).not_to be_valid
  end

  it "rejects progress outside 0..100" do
    expect(user.bookmarks.build(book: book, location: "1", progress: 120)).not_to be_valid
  end

  describe ".for" do
    before do
      user.bookmarks.create!(book: book, location: "30", progress: 30)
      user.bookmarks.create!(book: book, location: "5", progress: 5)
      create(:user).bookmarks.create!(book: book, location: "7", progress: 7)
    end

    it "lists only this reader's bookmarks, in book order" do
      expect(Bookmark.for(user: user, book: book).map(&:location)).to eq(%w[5 30])
    end

    context "with caching", :caching do
      it "serves a repeat lookup without touching the database" do
        Bookmark.for(user: user, book: book)

        expect(count_queries { Bookmark.for(user: user, book: book) }).to eq(0)
      end

      it "reflects a new bookmark" do
        Bookmark.for(user: user, book: book)
        travel(1.minute) { user.bookmarks.create!(book: book, location: "12", progress: 12) }

        expect(Bookmark.for(user: user, book: book).map(&:location)).to eq(%w[5 12 30])
      end
    end
  end
end
