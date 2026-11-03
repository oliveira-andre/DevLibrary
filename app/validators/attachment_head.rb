# Reads the first bytes of a pending Active Storage attachment, whatever form it arrived in:
# an uploaded file or IO (not yet stored) or a blob / signed blob id (already stored, e.g. a
# direct upload). Validators sniff these bytes instead of trusting the declared content type,
# which direct uploads never re-identify server-side (research R2).
module AttachmentHead
  BYTES = 4096

  module_function

  def read(change, length = BYTES)
    if (io = io_for(change.attachable))
      io.rewind if io.respond_to?(:rewind)
      head = io.read(length).to_s.b
      io.rewind if io.respond_to?(:rewind)
      head
    else
      change.blob.download_chunk(0...length).to_s.b
    end
  end

  def io_for(attachable)
    case attachable
    when Hash then attachable[:io]
    when ActiveStorage::Blob, String then nil
    else attachable if attachable.respond_to?(:read)
    end
  end

  def mime_type(head)
    Marcel::MimeType.for(StringIO.new(head)).to_s
  end

  # The change for a new attachment on this attribute, or nil when nothing new was attached.
  def pending_change(record, attribute)
    change = record.attachment_changes[attribute.to_s]
    change if change.respond_to?(:blob) && change.blob
  end
end
