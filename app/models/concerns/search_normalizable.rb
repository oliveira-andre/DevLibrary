# Normalizes text for accent- and case-insensitive search.
#
# Combining marks are removed only after Latin letters, so "Café" matches "cafe" while
# Japanese kana keep their dakuten ("バ" stays "バ", it does not collapse into "ハ").
module SearchNormalizable
  extend ActiveSupport::Concern

  module_function

  def normalize(text)
    text.to_s
      .unicode_normalize(:nfd)
      .gsub(/(\p{Latin})\p{Mn}+/, '\1')
      .unicode_normalize(:nfc)
      .downcase
      .squish
  end
end
