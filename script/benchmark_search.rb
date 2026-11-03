# Measures catalog search speed on 10,000 published books (spec SC-007: p95 under 1 second).
# Inserts the books inside a transaction that is rolled back, so the database is unchanged.
#
#   bin/rails runner script/benchmark_search.rb

BOOKS = 10_000
QUERIES = 200
WORDS = %w[dragon shadow café noir river moon garden empire song winter crown storm ocean ninja
  samurai detective love ghost forest tower letters night crystal saga].freeze

samples = []

ActiveRecord::Base.transaction do
  now = Time.current
  rows = Array.new(BOOKS) do |n|
    title = "#{WORDS.sample(3).join(' ').capitalize} #{n}"
    author = "Author #{n % 500}"
    {
      title: title,
      authors: [ author ],
      status: "published",
      kind: %w[book comic manga storybook].sample,
      reading_direction: "ltr",
      public_id: SecureRandom.base58(12),
      search_text: SearchNormalizable.normalize("#{title} #{author}"),
      published_at: now - rand(0..1000).days,
      average_rating: rand(0.0..5.0).round(2),
      reviews_count: rand(0..300),
      created_at: now,
      updated_at: now
    }
  end
  rows.each_slice(2_000) { |slice| Book.insert_all!(slice) }
  ActiveRecord::Base.connection.execute("ANALYZE books")

  sorts = Book::Search::SORTS
  QUERIES.times do
    query = WORDS.sample(rand(1..2)).join(" ")
    search = Book::Search.new(query: query, sort: sorts.sample)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    search.scope.limit(search.per).to_a # cache bypassed on purpose
    samples << Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  raise ActiveRecord::Rollback
end

samples.sort!
p95 = samples[(samples.size * 0.95).ceil - 1]
puts format("%d searches over %d books: median %.1f ms, p95 %.1f ms, max %.1f ms",
  samples.size, BOOKS, samples[samples.size / 2] * 1000, p95 * 1000, samples.last * 1000)
puts p95 < 1.0 ? "PASS: p95 under 1 second (SC-007)" : "FAIL: p95 is 1 second or more (SC-007)"
exit(p95 < 1.0 ? 0 : 1)
