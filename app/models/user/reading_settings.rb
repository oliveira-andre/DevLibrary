# How a person likes to read, saved on the account so it follows them to every book and
# device (002 FR-031–FR-034, research R7): page-turn animation, reader theme and text size.
# The reader reads these from Current.user, which authentication already loaded.
module User::ReadingSettings
  extend ActiveSupport::Concern

  TEXT_SIZES = [ 80, 90, 100, 115, 130, 150, 175 ].freeze
  ATTRIBUTES = %i[ reader_page_animation reader_theme reader_text_size ].freeze

  included do
    enum :reader_theme, { light: "light", sepia: "sepia", dark: "dark" }, prefix: true, validate: true

    validates :reader_text_size, inclusion: { in: TEXT_SIZES }
    validates :reader_page_animation, inclusion: { in: [ true, false ] }
  end

  def reading_settings
    { page_animation: reader_page_animation, theme: reader_theme, text_size: reader_text_size }
  end

  # Only the three settings are taken from `attrs`; anything else is ignored.
  def update_reading_settings(attrs)
    update(attrs.to_h.symbolize_keys.slice(*ATTRIBUTES))
  end
end
