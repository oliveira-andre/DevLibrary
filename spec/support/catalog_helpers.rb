# Inserts many published books at once for specs that only need catalog rows (paging,
# ordering), skipping file attachments and callbacks. Each book gets its own published_at,
# one minute apart; the newest is `newest_at`. Returns the books oldest first.
module CatalogHelpers
  def insert_published_books(count, newest_at: Time.current, title: "Catalog Book")
    now = Time.current
    rows = Array.new(count) do |i|
      name = format("%s %03d", title, i + 1)
      {
        title: name, authors: [], kind: "book", reading_direction: "ltr", status: "published",
        published_at: newest_at - (count - 1 - i).minutes, public_id: SecureRandom.base58(12),
        search_text: SearchNormalizable.normalize(name), file_format: "pdf", created_at: now, updated_at: now
      }
    end
    Book.insert_all!(rows)
    Book.where(public_id: rows.pluck(:public_id)).order(:published_at, :id).to_a
  end
end

RSpec.configure do |config|
  config.include CatalogHelpers
end
