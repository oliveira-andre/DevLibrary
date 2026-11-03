class ShelfPlacement < ApplicationRecord
  belongs_to :shelf, touch: true
  belongs_to :library_entry, touch: true

  validates :library_entry_id, uniqueness: { scope: :shelf_id }
  validate :same_library

  private
    def same_library
      return unless shelf && library_entry

      if shelf.library_id != library_entry.library_id
        errors.add(:library_entry, "must belong to the same library as the shelf")
      end
    end
end
