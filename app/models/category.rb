class Category < ApplicationRecord
  has_many :categorizations, dependent: :destroy
  has_many :books, through: :categorizations

  normalizes :name, with: ->(n) { n.squish }

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { case_sensitive: false }

  # Book cards show category names, so a rename must invalidate every cached catalog read.
  after_save -> { books.touch_all }, if: :saved_change_to_name?

  # For the search page's category dropdown.
  def self.cached_ordered
    relation = order(:name)
    Rails.cache.fetch([ "categories", relation.cache_key_with_version ]) { relation.to_a }
  end
end
