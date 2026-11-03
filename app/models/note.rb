# A reader's private note on a book, tied to where they were reading. Never changes the book.
class Note < ApplicationRecord
  MAX_LENGTH = 10_000

  belongs_to :user, touch: true
  belongs_to :book

  has_rich_text :content

  validates :location, presence: true
  validates :progress, numericality: { in: 0..100 }
  validate :content_present_and_within_limit

  scope :in_book_order, -> { order(:progress, :created_at) }

  def self.for(user:, book:)
    Rails.cache.fetch([ user.cache_key_with_version, "notes", book.id ]) do
      user.notes.where(book: book).in_book_order.with_rich_text_content.to_a
    end
  end

  private
    def content_present_and_within_limit
      text = content&.to_plain_text.to_s.strip
      if text.empty?
        errors.add(:content, :blank)
      elsif text.length > MAX_LENGTH
        errors.add(:content, :too_long, count: MAX_LENGTH)
      end
    end
end
