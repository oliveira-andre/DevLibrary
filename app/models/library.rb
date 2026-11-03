# A reader's private collection: the books they keep, sorted onto shelves they create.
# Every account has exactly one, created with it, holding the built-in Favorites shelf.
class Library < ApplicationRecord
  belongs_to :user, touch: true

  has_many :entries, class_name: "LibraryEntry", dependent: :destroy
  has_many :books, through: :entries
  has_many :shelves, dependent: :destroy
  has_one :favorites_shelf, -> { kind_favorites }, class_name: "Shelf"

  after_create { create_favorites_shelf!(name: Shelf::FAVORITES_NAME) }

  def add!(book)
    entries.find_or_create_by!(book: book)
  rescue ActiveRecord::RecordNotUnique
    entries.find_by!(book: book)
  end

  # Removes the book from the library and every shelf. The catalog book, reading position,
  # bookmarks and notes are left alone, so adding it back restores them (FR-028).
  def remove!(book)
    if (entry = entries.find_by(book: book))
      entries.destroy(entry)
    end
    true
  end

  def favorite!(book)
    place!(book, shelf: favorites_shelf)
  end

  def unfavorite!(book)
    unplace!(book, shelf: favorites_shelf)
  end

  def favorited?(book)
    favorites_shelf.entries.exists?(book_id: book.id)
  end

  def place!(book, shelf:)
    transaction do
      shelf.shelf_placements.find_or_create_by!(library_entry: add!(book))
    end
    true
  end

  def unplace!(book, shelf:)
    if (entry = entries.find_by(book: book))
      shelf.shelf_placements.where(library_entry: entry).destroy_all
    end
    true
  end

  # Entries matching the text (title or authors) and/or shelf, most recently read first, then
  # most recently added. Each entry carries the book (cover preloaded) and the reader's saved
  # position as `reading_location`, `reading_progress` and `last_read_at` (FR-033, FR-034).
  def search(query: nil, shelf: nil)
    normalized = SearchNormalizable.normalize(query)

    Rails.cache.fetch([ user.cache_key_with_version, "library", Book.catalog_version, normalized, shelf&.id ]) do
      scope = entries.joins(:book).joins(reading_positions_join).includes(book: { cover_attachment: :blob })
      scope = scope.joins(:shelf_placements).where(shelf_placements: { shelf_id: shelf.id }) if shelf
      normalized.split.each do |term|
        scope = scope.where("books.search_text LIKE ?", "%#{Book.sanitize_sql_like(term)}%")
      end
      scope
        .select("library_entries.*", "reading_positions.location AS reading_location",
                "reading_positions.progress AS reading_progress", "reading_positions.read_at AS last_read_at")
        .order(Arel.sql("reading_positions.read_at DESC NULLS LAST, library_entries.created_at DESC"))
        .to_a
    end
  end

  private
    def reading_positions_join
      self.class.sanitize_sql_array([
        "LEFT JOIN reading_positions ON reading_positions.book_id = library_entries.book_id " \
        "AND reading_positions.user_id = ?", user_id
      ])
    end
end
