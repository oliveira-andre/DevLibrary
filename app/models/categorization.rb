class Categorization < ApplicationRecord
  belongs_to :book, touch: true
  belongs_to :category, touch: true

  validates :category_id, uniqueness: { scope: :book_id }
end
