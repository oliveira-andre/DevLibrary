require "rails_helper"

RSpec.describe Review, type: :model do
  let(:book) { create(:book, :published) }

  def review(rating: 4, content: "Loved it ❤️", user: create(:user), on: book)
    on.reviews.build(user: user, rating: rating, content: content)
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:book) }

  describe "rating" do
    [ 0, 6, "3.5", nil ].each do |bad|
      it "rejects #{bad.inspect}" do
        expect(review(rating: bad)).not_to be_valid
      end
    end

    [ 1, 5 ].each do |good|
      it "accepts #{good}" do
        expect(review(rating: good)).to be_valid
      end
    end
  end

  it "requires written content of at most 5,000 characters" do
    expect(review(content: "")).not_to be_valid
    expect(review(content: "a" * 5_000)).to be_valid
    expect(review(content: "a" * 5_001)).not_to be_valid
  end

  it "keeps emoji in the content" do
    saved = review(content: "Masterpiece 🤯👏🏾").tap(&:save!)

    expect(saved.reload.content.to_plain_text).to eq("Masterpiece 🤯👏🏾")
  end

  it "allows one review per reader per book" do
    reader = create(:user)
    review(user: reader).save!

    duplicate = review(user: reader)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to include("has already been taken")
  end

  it "is only allowed on published books" do
    expect(review(on: create(:book))).not_to be_valid
  end

  describe "the book's average rating and review count" do
    it "is updated on create, update and destroy" do
      four = review(rating: 4).tap(&:save!)
      two = review(rating: 2).tap(&:save!)
      expect(book.reload).to have_attributes(average_rating: 3.0, reviews_count: 2)

      two.update!(rating: 5)
      expect(book.reload).to have_attributes(average_rating: 4.5, reviews_count: 2)

      two.destroy!
      expect(book.reload).to have_attributes(average_rating: 4.0, reviews_count: 1)

      four.destroy!
      expect(book.reload).to have_attributes(average_rating: 0, reviews_count: 0)
    end

    it "is not recalculated while the book itself is being destroyed" do
      review.save!
      expect_any_instance_of(Book).not_to receive(:refresh_rating!)

      book.destroy!
    end

    it "is updated when a reviewer's account is deleted" do
      reviewer = create(:user)
      review(rating: 5, user: reviewer).save!
      review(rating: 3).save!

      reviewer.destroy!

      expect(book.reload).to have_attributes(average_rating: 3.0, reviews_count: 1)
    end
  end

  it "bumps the book when the reviewer is renamed" do
    reviewer = create(:user, name: "Ana")
    review(user: reviewer).save!

    travel 1.minute do
      expect { reviewer.update!(name: "Ana Souza") }.to change { book.reload.updated_at }
    end
  end

  describe ".for_book", :caching do
    before { review(rating: 5, user: create(:user, name: "Ana")).save! }

    it "serves a repeat page without touching the database" do
      Review.for_book(book, page: 1)

      expect(count_queries { Review.for_book(book, page: 1) }).to eq(0)
    end

    it "reflects a new review" do
      Review.for_book(book, page: 1)
      travel(1.minute) { review(rating: 2).save! }

      expect(Review.for_book(book.reload, page: 1).size).to eq(2)
    end

    it "reflects a renamed reviewer" do
      Review.for_book(book, page: 1)
      travel(1.minute) { Review.first.user.update!(name: "Ana Souza") }

      expect(Review.for_book(book.reload, page: 1).first.user.name).to eq("Ana Souza")
    end
  end
end
