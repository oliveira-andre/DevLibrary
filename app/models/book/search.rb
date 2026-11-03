# Catalog search behind the home/search page: text + one category + sort (FR-023–FR-026).
# Only published books. Results are cached per catalog version, so any catalog write
# (book, category, categorization, review, conversion) invalidates them.
class Book::Search
  SORTS = %w[relevance newest title_asc title_desc top_rated].freeze
  DEFAULT_PER = 24
  MAX_PER = 100

  attr_reader :query, :category, :sort, :page, :per

  def initialize(query: nil, category: nil, sort: nil, page: 1, per: DEFAULT_PER)
    @query = SearchNormalizable.normalize(query)
    @category = category
    @sort = resolve_sort(sort.to_s)
    @page = [ page.to_i, 1 ].max
    @per = per.to_i.clamp(1, MAX_PER)
  end

  def results
    Rails.cache.fetch([ "catalog/search", Book.catalog_version, query, category&.id, sort, page, per ]) do
      scope.with_attached_cover.limit(per).offset((page - 1) * per).to_a
    end
  end

  def scope
    relation = Book.published
    relation = relation.where(id: Categorization.where(category: category).select(:book_id)) if category
    query.split.each do |term|
      relation = relation.where("books.search_text LIKE ?", "%#{Book.sanitize_sql_like(term)}%")
    end
    relation.order(order_clause)
  end

  private
    def resolve_sort(requested)
      default = query.empty? ? "newest" : "relevance"
      return default unless SORTS.include?(requested)
      return "newest" if requested == "relevance" && query.empty?

      requested
    end

    def order_clause
      case sort
      when "relevance"
        Arel.sql(Book.sanitize_sql_array([
          "word_similarity(?, books.search_text) DESC, similarity(?, books.search_text) DESC, books.title ASC",
          query, query
        ]))
      when "newest" then { published_at: :desc, id: :desc }
      when "title_asc" then { title: :asc, id: :asc }
      when "title_desc" then { title: :desc, id: :desc }
      when "top_rated" then { average_rating: :desc, reviews_count: :desc, id: :desc }
      end
    end
end
