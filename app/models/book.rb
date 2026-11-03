class Book < ApplicationRecord
  has_rich_text :description
  # Cards and the collection row show covers at up to 240×360 CSS px, the book page at up
  # to 300×450, both at 2× density (002 data-model.md). Generated when the cover is attached.
  has_one_attached :cover do |cover|
    cover.variant :card, resize_to_fill: [ 480, 720 ], format: :webp, preprocessed: true
    cover.variant :large, resize_to_limit: [ 600, 900 ], format: :webp, preprocessed: true
  end
  has_one_attached :file

  has_many :categorizations, dependent: :destroy
  has_many :categories, through: :categorizations
  has_many :library_entries, dependent: :destroy
  has_many :reading_positions, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :conversions, dependent: :destroy

  enum :kind, { book: "book", comic: "comic", manga: "manga", storybook: "storybook" }, prefix: true, validate: true
  enum :reading_direction, { ltr: "ltr", rtl: "rtl" }, default: nil, validate: true
  enum :status, { draft: "draft", published: "published", archived: "archived" }, validate: true

  # Set by BookFileValidator from the uploaded bytes; persisted as file_format.
  attr_accessor :detected_file_format

  validates :title, presence: true, length: { maximum: 255 }
  validates :file, book_file: true
  validates :file, presence: { message: "is required to publish" }, if: :published?
  validates :cover, cover_image: true

  before_validation :assign_default_reading_direction
  before_validation :assign_public_id, on: :create
  before_save :assign_search_text, :assign_file_format, :assign_published_at
  after_save :discard_stale_conversions, if: -> { attachment_changes["file"].present? }

  # Admins see everything. Readers see published books, plus archived books they already
  # keep in their library (FR-017).
  scope :visible_to, ->(user) {
    if user.admin?
      all
    else
      published.or(archived.where(id: LibraryEntry.where(library: user.library).select(:book_id)))
    end
  }

  # Share links resolve through here: drafts (for readers) and deleted books raise
  # RecordNotFound; archived books only resolve for readers who keep them (FR-053–FR-055).
  def self.find_visible!(public_id, user:)
    visible_to(user).find_by!(public_id: public_id)
  end

  # The book page and the reader look books up through here: find_visible! plus what those
  # pages render, cached per catalog version and per reader, because archived visibility
  # depends on the reader's library (002 data-model.md).
  def self.find_visible_cached!(public_id, user:)
    book = Rails.cache.fetch([ "book/visible", catalog_version, public_id.to_s, user.cache_key_with_version ]) do
      visible_to(user).with_attached_cover.with_attached_file
        .includes(:categories, :rich_text_description)
        .find_by(public_id: public_id.to_s)
    end
    book || raise(ActiveRecord::RecordNotFound.new("Couldn't find Book with public_id=#{public_id}", name))
  end

  def self.recent(before: nil, per: Book::Recent::PER)
    Book::Recent.new(before: before, per: per).page
  end

  def self.search(query: nil, category: nil, sort: nil, page: 1, per: Book::Search::DEFAULT_PER)
    Book::Search.new(query: query, category: category, sort: sort, page: page, per: per).results
  end

  # Changes whenever any book is created, updated or destroyed; part of every catalog cache key.
  def self.catalog_version
    count, latest = unscoped.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(updated_at)"))
    "#{count}-#{latest&.to_fs(:usec)}"
  end

  def to_param
    public_id
  end

  def publish!
    update!(status: :published)
  end

  def archive!
    update!(status: :archived)
  end

  def unpublish!
    update!(status: :draft)
  end

  def current_file_checksum
    file.blob&.checksum
  end

  def convertible_to?(format)
    Conversion.target_formats.key?(format.to_s) && format.to_s != file_format
  end

  # Recomputes the denormalized average and count from the reviews in one query (FR-047),
  # bumping updated_at so every cached read of this book is invalidated.
  def refresh_rating!
    average, count = reviews.pick(Arel.sql("COALESCE(AVG(rating), 0)"), Arel.sql("COUNT(*)"))
    update_columns(average_rating: average.to_d.round(2), reviews_count: count, updated_at: Time.current)
  end

  private
    def assign_default_reading_direction
      if reading_direction.blank? || (persisted? && kind_changed? && !reading_direction_changed?)
        self.reading_direction = kind_manga? ? "rtl" : "ltr"
      end
    end

    def assign_public_id
      self.public_id ||= loop do
        candidate = SecureRandom.base58(12)
        break candidate unless Book.exists?(public_id: candidate)
      end
    end

    def assign_search_text
      self.search_text = SearchNormalizable.normalize([ title, *authors ].join(" "))
    end

    def assign_file_format
      self.file_format = detected_file_format if detected_file_format
    end

    def assign_published_at
      self.published_at ||= Time.current if status_changed? && published?
    end

    # A replaced file makes every conversion of the old bytes obsolete (FR-051).
    def discard_stale_conversions
      conversions.where.not(source_checksum: current_file_checksum).destroy_all
    end
end
