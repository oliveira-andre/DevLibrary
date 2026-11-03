# Where a reader is in a book, so it reopens on the same page on any device (Principle V).
# One row per reader and book, independent of the library. The newest reading event wins.
class ReadingPosition < ApplicationRecord
  FUTURE_TOLERANCE = 1.minute

  belongs_to :user, touch: true
  belongs_to :book

  enum :reading_direction, { ltr: "ltr", rtl: "rtl" }, prefix: :override, validate: { allow_nil: true }

  validates :progress, numericality: { in: 0..100 }

  # Saves a page turn. `read_at` is the device's time of the event; an update older than
  # the stored one (e.g. from a device that was offline) is ignored, and a device clock far
  # in the future is clamped to now so it cannot freeze the position.
  def self.record!(user:, book:, location:, progress:, read_at:)
    read_at = ActiveModel::Type::DateTime.new.cast(read_at) || Time.current
    read_at = Time.current if read_at > FUTURE_TOLERANCE.from_now

    create_or_find_by!(user: user, book: book).tap do |position|
      position.with_lock do
        position.user = user # touch the caller's user object so its cache version moves too
        if position.read_at.nil? || read_at > position.read_at
          position.update!(location: location, progress: progress, read_at: read_at)
        end
      end
    end
  end

  # Sets (or with nil, clears) the reader's own direction for this book.
  def self.set_direction!(user:, book:, direction:)
    create_or_find_by!(user: user, book: book).tap do |position|
      position.user = user
      position.update!(reading_direction: direction)
    end
  end

  def self.for(user:, book:)
    Rails.cache.fetch([ user.cache_key_with_version, "reading_position", book.id ]) do
      find_by(user: user, book: book)
    end
  end

  def effective_reading_direction
    reading_direction || book.reading_direction
  end
end
