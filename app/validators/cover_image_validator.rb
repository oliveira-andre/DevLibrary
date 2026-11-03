# Accepts JPEG, PNG and WebP covers up to 10 MB, identified from their bytes (FR-014).
class CoverImageValidator < ActiveModel::EachValidator
  MAX_SIZE = 10.megabytes
  ALLOWED_TYPES = %w[image/jpeg image/png image/webp].freeze

  def validate_each(record, attribute, _value)
    change = AttachmentHead.pending_change(record, attribute)
    return unless change

    if change.blob.byte_size.to_i > MAX_SIZE
      record.errors.add(attribute, "must be 10 MB or smaller")
    elsif !ALLOWED_TYPES.include?(AttachmentHead.mime_type(AttachmentHead.read(change)))
      record.errors.add(attribute, "must be a JPEG, PNG or WebP image")
    end
  end
end
