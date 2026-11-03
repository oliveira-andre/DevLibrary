require "rails_helper"

RSpec.describe "Book file delivery", type: :request do
  let(:reader) { create(:user) }
  let(:book) { create(:book, :published) } # sample.pdf, 592 bytes
  let(:size) { book.file.blob.byte_size }

  before { sign_in_as(reader) }

  it "streams the whole original with the headers pdf.js needs for range mode" do
    get book_file_path(book)

    expect(response).to have_http_status(:ok)
    expect(response.body.bytesize).to eq(size)
    expect(response.headers["Accept-Ranges"]).to eq("bytes")
    expect(response.headers["Content-Length"]).to eq(size.to_s)
    expect(response.headers["Cache-Control"]).to eq("private, no-store")
    expect(response.headers["Content-Encoding"]).to be_nil
    expect(response.media_type).to eq("application/pdf")
  end

  it "answers a byte range with 206 and just those bytes" do
    get book_file_path(book), headers: { "Range" => "bytes=0-99" }

    expect(response).to have_http_status(:partial_content)
    expect(response.headers["Content-Range"]).to eq("bytes 0-99/#{size}")
    expect(response.body.bytesize).to eq(100)
    expect(response.body).to eq(File.binread(file_fixture("sample.pdf"))[0, 100])
  end

  it "refuses a range past the end" do
    get book_file_path(book), headers: { "Range" => "bytes=#{size + 10}-#{size + 20}" }

    expect(response).to have_http_status(:range_not_satisfiable)
  end

  it "answers HEAD with the length, so zip readers can seek" do
    head book_file_path(book)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Length"]).to eq(size.to_s)
    expect(response.headers["Accept-Ranges"]).to eq("bytes")
  end

  it "still serves an archived book to a reader who keeps it" do
    reader.library.add!(book)
    book.archive!

    get book_file_path(book)

    expect(response).to have_http_status(:ok)
  end

  it "answers 404 for a draft" do
    get book_file_path(create(:book, :with_file))

    expect(response).to have_http_status(:not_found)
  end

  it "sends signed-out visitors to sign-in" do
    delete session_path
    get book_file_path(book)

    expect(response).to redirect_to(new_session_path)
  end
end
