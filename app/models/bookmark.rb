class Bookmark < ApplicationRecord
  belongs_to :user, touch: true
  belongs_to :book

  validates :location, presence: true, uniqueness: { scope: [ :user_id, :book_id ] }
  validates :label, length: { maximum: 100 }
  validates :progress, numericality: { in: 0..100 }

  scope :in_book_order, -> { order(:progress, :created_at) }

  def self.for(user:, book:)
    Rails.cache.fetch([ user.cache_key_with_version, "bookmarks", book.id ]) do
      user.bookmarks.where(book: book).in_book_order.to_a
    end
  end
end
