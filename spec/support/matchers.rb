RSpec::Matchers.define_negated_matcher :not_change, :change

# Retries a block until the inner matcher passes, for values the browser settles on
# asynchronously (a scroll position after a smooth scroll, a reader location after a turn).
#
#   expect { row_scroll_left }.to eventually(be > 0)
RSpec::Matchers.define :eventually do |inner|
  supports_block_expectations

  match do |block|
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 6
    loop do
      @actual = block.call
      break true if inner.matches?(@actual)
      break false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  failure_message { "expected #{@actual.inspect} to eventually #{inner.description}" }
end
