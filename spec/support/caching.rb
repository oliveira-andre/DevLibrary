# Examples tagged `:caching` run against a real in-memory store so cache hits and
# invalidations can be asserted. Everything else keeps the test env's :null_store.
RSpec.configure do |config|
  config.before(:each, :caching) do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end
end
