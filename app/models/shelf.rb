class Shelf < ApplicationRecord
  FAVORITES_NAME = "Favorites".freeze

  belongs_to :library, touch: true

  has_many :shelf_placements, dependent: :destroy
  has_many :entries, through: :shelf_placements, source: :library_entry

  enum :kind, { favorites: "favorites", custom: "custom" }, prefix: true, validate: true

  normalizes :name, with: ->(n) { n.squish }

  validates :name, presence: true, length: { maximum: 50 }, uniqueness: { scope: :library_id, case_sensitive: false }
  validate :name_not_reserved, if: :kind_custom?
  validate :favorites_not_renamed, on: :update

  before_destroy :protect_favorites

  private
    def name_not_reserved
      errors.add(:name, "is reserved") if name.to_s.casecmp?(FAVORITES_NAME)
    end

    def favorites_not_renamed
      errors.add(:name, "can't be changed for Favorites") if kind_favorites? && name_changed?
    end

    def protect_favorites
      throw :abort if kind_favorites? && !destroyed_by_association
    end
end
