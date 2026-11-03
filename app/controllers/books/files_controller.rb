# Delivers a book's original file to signed-in readers who may see it (002 research R6).
# The session authorizes every request, so pdf.js and zip.js can keep fetching byte ranges
# for as long as the book is open. Nothing is cached outside the reader's own browser.
#
# Ranges are read from storage chunk by chunk; a full download streams through an Enumerator
# body, so a 500 MB file is never held in memory and no ActionController::Live thread is
# needed (Live threads and a shared test database connection block server shutdown).
class Books::FilesController < ApplicationController
  include BookScoped

  def show
    blob = @book.file.blob
    return head(:not_found) unless blob

    response.headers["Accept-Ranges"] = "bytes"
    response.headers["Cache-Control"] = "private, no-store"

    ranges = Rack::Utils.get_byte_ranges(request.headers["Range"], blob.byte_size) if request.headers["Range"]
    if request.head?
      response.headers["Content-Length"] = blob.byte_size.to_s
      head :ok, content_type: blob.content_type_for_serving
    elsif ranges&.empty? || ranges&.sum(&:size).to_i > ActiveStorage.streaming_chunk_max_size
      response.headers["Content-Range"] = "bytes */#{blob.byte_size}"
      head :range_not_satisfiable
    elsif ranges&.one?
      send_range blob, ranges.first
    else
      # No Range (or several, which the readers never ask for): the whole file, with a known
      # length, which is what lets pdf.js switch to range requests.
      stream_whole blob
    end
  end

  private
    def send_range(blob, range)
      response.headers["Content-Range"] = "bytes #{range.begin}-#{range.end}/#{blob.byte_size}"
      send_data blob.download_chunk(range), type: blob.content_type_for_serving, disposition: :inline,
                filename: blob.filename.sanitized, status: :partial_content
    end

    def stream_whole(blob)
      response.headers["Content-Length"] = blob.byte_size.to_s
      response.headers["Content-Type"] = blob.content_type_for_serving
      response.headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
        disposition: "inline", filename: blob.filename.sanitized)
      self.response_body = Enumerator.new { |body| blob.download { |chunk| body << chunk } }
    end
end
