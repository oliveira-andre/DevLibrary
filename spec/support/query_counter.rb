module QueryCounter
  IGNORED_NAMES = %w[SCHEMA TRANSACTION].freeze

  # Returns how many SQL statements the block sent to the database.
  # Schema lookups, transaction/savepoint statements and query-cache hits are ignored.
  def count_queries(&block)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless IGNORED_NAMES.include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end

RSpec.configure do |config|
  config.include QueryCounter
end
