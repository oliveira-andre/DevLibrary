# A PDF or EPUB copy of one version of a book's file, shared by everyone who asks for it
# (FR-049–FR-051). The original file is never touched; the copy lives in `output`.
# This model only stores the state; the conversion job is a later feature.
class Conversion < ApplicationRecord
  belongs_to :book, touch: true
  belongs_to :requested_by, class_name: "User", optional: true

  has_one_attached :output

  enum :target_format, { pdf: "pdf", epub: "epub" }, prefix: :to, validate: true
  enum :status, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }, validate: true

  validates :source_checksum, presence: true
  validates :output, presence: true, if: :completed?
  validate :target_differs_from_original
  validate :book_file_attached

  # Idempotent per (book, current file version, format). A failed one is queued again.
  def self.request!(book:, target_format:, user:)
    conversion = create_or_find_by!(book: book, source_checksum: book.current_file_checksum, target_format: target_format) do |c|
      c.requested_by = user
    end
    conversion.retry! if conversion.failed?
    conversion
  end

  def start!
    update!(status: :processing)
  end

  def complete!(io:, filename:)
    update!(output: { io: io, filename: filename }, status: :completed, failure_reason: nil)
  end

  def fail!(reason)
    update!(status: :failed, failure_reason: reason)
  end

  # Keeps the last failure reason until a later attempt succeeds.
  def retry!
    update!(status: :pending, attempts: attempts + 1)
  end

  private
    def target_differs_from_original
      if book && target_format.present? && target_format == book.file_format
        errors.add(:target_format, "can't be the book's own format")
      end
    end

    def book_file_attached
      errors.add(:book, "has no file to convert") if book && !book.file.attached?
    end
end
