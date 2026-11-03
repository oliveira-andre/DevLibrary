class LibraryEntry < ApplicationRecord
  belongs_to :library, touch: true
  belongs_to :book

  has_many :shelf_placements, dependent: :destroy
  has_many :shelves, through: :shelf_placements

  validates :book_id, uniqueness: { scope: :library_id }
  validate :book_must_be_published, on: :create

  private
    def book_must_be_published
      errors.add(:book, "must be published") if book && !book.published?
    end
end
