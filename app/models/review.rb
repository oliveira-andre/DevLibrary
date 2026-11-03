class Review < ApplicationRecord
  MAX_LENGTH = 5_000

  belongs_to :user
  belongs_to :book

  has_rich_text :content

  # Runs on the raw input, so "3.5" is rejected instead of being truncated to 3.
  validates :rating, numericality: { only_integer: true, in: 1..5 }
  validates :user_id, uniqueness: { scope: :book_id }
  validate :book_must_be_published, on: :create
  validate :content_present_and_within_limit

  # Inside the transaction, so no read after commit sees a stale average (research R9).
  after_save :refresh_book_rating
  after_destroy :refresh_book_rating, unless: -> { destroyed_by_association&.active_record == Book }

  def self.for_book(book, page:, per: 20)
    Rails.cache.fetch([ "book", book.cache_key_with_version, "reviews", page, per ]) do
      book.reviews.includes(:user).with_rich_text_content
        .order(created_at: :desc).limit(per).offset((page - 1) * per).to_a
    end
  end

  private
    def refresh_book_rating
      book.refresh_rating!
    end

    def book_must_be_published
      errors.add(:book, "must be published") if book && !book.published?
    end

    def content_present_and_within_limit
      text = content&.to_plain_text.to_s.strip
      if text.empty?
        errors.add(:content, :blank)
      elsif text.length > MAX_LENGTH
        errors.add(:content, :too_long, count: MAX_LENGTH)
      end
    end
end
