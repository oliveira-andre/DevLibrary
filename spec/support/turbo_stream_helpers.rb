# Request-spec helpers for Turbo Stream responses. Rails leaves `parsed_body` as a String for
# this media type, so the body is parsed here; each stream's <template> content is searchable.
module TurboStreamHelpers
  def turbo_stream_doc
    Nokogiri::HTML(response.body)
  end

  # The <turbo-stream> element for an action on a target, e.g. turbo_stream_for("append", "reviews").
  def turbo_stream_for(action, target)
    turbo_stream_doc.at_css("turbo-stream[action='#{action}'][target='#{target}']")
  end
end

RSpec.configure do |config|
  config.include TurboStreamHelpers, type: :request
end
