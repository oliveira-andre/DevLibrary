# Accepts PDF, EPUB, CBZ and CBR book files, identified from their bytes (FR-014).
# On success the detected format is handed to the record as `detected_file_format`.
class BookFileValidator < ActiveModel::EachValidator
  MAX_SIZE = 500.megabytes
  EPUB_MARKER = "mimetypeapplication/epub+zip".b

  def validate_each(record, attribute, _value)
    change = AttachmentHead.pending_change(record, attribute)
    return unless change

    if change.blob.byte_size.to_i > MAX_SIZE
      record.errors.add(attribute, "must be 500 MB or smaller")
    elsif (format = self.class.detect(AttachmentHead.read(change), change.blob.filename))
      record.detected_file_format = format
    else
      record.errors.add(attribute, "is an unsupported or unreadable file")
    end
  end

  def self.detect(head, filename)
    type = AttachmentHead.mime_type(head)
    extension = filename.extension_without_delimiter.to_s.downcase

    if type == "application/pdf"
      "pdf"
    elsif head.byteslice(30, EPUB_MARKER.bytesize) == EPUB_MARKER
      "epub"
    elsif type == "application/zip" && extension == "cbz"
      "cbz"
    elsif type.start_with?("application/x-rar") && extension == "cbr"
      "cbr"
    end
  end
end
