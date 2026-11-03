class User < ApplicationRecord
  include Lockable
  include ReadingSettings

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one :library, dependent: :destroy
  has_many :reading_positions, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :requested_conversions, class_name: "Conversion", foreign_key: :requested_by_id, dependent: :nullify

  after_create :create_library!
  # Reviews show the author's name, so a rename must invalidate those books' cached reads.
  after_save -> { Book.where(id: reviews.select(:book_id)).touch_all }, if: :saved_change_to_name?

  enum :role, { reader: "reader", admin: "admin" }, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.strip }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { in: 8..72 }, allow_nil: true
  validates :name, length: { maximum: 100 }
  validates :name, presence: true, on: :sign_up
  validate :name_not_cleared, on: :update

  private
    def name_not_cleared
      errors.add(:name, :blank) if name_was.present? && name.blank?
    end
end
