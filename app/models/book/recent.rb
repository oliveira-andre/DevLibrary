# The newest published books on the home page, 50 at a time (002 FR-003, FR-004). Keyset
# pagination on (published_at, id): publishing or deleting a book between batches can never
# make the next batch repeat or skip one (research R3). Batches are cached per catalog
# version, so any catalog write shows up on the next load.
class Book::Recent
  PER = 50

  def initialize(before: nil, per: PER)
    @cursor = decode(before)
    @per = per
  end

  def page
    books = Rails.cache.fetch([ "catalog/recent", Book.catalog_version, @cursor, @per ]) do
      scope.limit(@per + 1).to_a
    end
    more = books.size > @per
    books = books.first(@per)

    Book::Page.new(books: books, next_params: more ? { before: encode(books.last) } : nil)
  end

  private
    def scope
      relation = Book.published.with_attached_cover.order(published_at: :desc, id: :desc)
      return relation unless @cursor

      published_at, id = @cursor
      relation.where("(books.published_at, books.id) < (?, ?)", Time.iso8601(published_at), id)
    end

    def encode(book)
      Base64.urlsafe_encode64("#{book.published_at.utc.iso8601(6)}|#{book.id}", padding: false)
    end

    # A cursor that doesn't decode to a time and an id means "first batch", never an error.
    def decode(cursor)
      return if cursor.blank?

      time, id = Base64.urlsafe_decode64(cursor.to_s).split("|", 2)
      [ Time.iso8601(time).utc.iso8601(6), Integer(id) ]
    rescue ArgumentError, TypeError
      nil
    end
end
