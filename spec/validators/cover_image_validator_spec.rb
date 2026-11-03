require "rails_helper"

RSpec.describe CoverImageValidator, type: :model do
  def book_with_cover(fixture, filename: fixture)
    build(:book).tap { |book| book.cover.attach(io: file_fixture(fixture).open, filename: filename) }
  end

  %w[cover.jpg cover.png cover.webp].each do |fixture|
    it "accepts #{fixture}" do
      expect(book_with_cover(fixture)).to be_valid
    end
  end

  it "rejects GIF images" do
    book = book_with_cover("cover.gif")

    expect(book).not_to be_valid
    expect(book.errors[:cover]).to include("must be a JPEG, PNG or WebP image")
  end

  it "rejects a PDF renamed to .png" do
    expect(book_with_cover("sample.pdf", filename: "x.png")).not_to be_valid
  end

  it "rejects images larger than 10 MB" do
    book = book_with_cover("cover.png")
    allow(book.attachment_changes["cover"].blob).to receive(:byte_size).and_return(10.megabytes + 1)

    expect(book).not_to be_valid
    expect(book.errors[:cover]).to include("must be 10 MB or smaller")
  end
end
