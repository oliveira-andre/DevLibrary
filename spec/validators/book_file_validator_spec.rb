require "rails_helper"

RSpec.describe BookFileValidator, type: :model do
  def book_with(fixture, filename: fixture, content_type: nil)
    attachable = { io: file_fixture(fixture).open, filename: filename }
    attachable[:content_type] = content_type if content_type
    build(:book).tap { |book| book.file.attach(attachable) }
  end

  {
    "sample.pdf" => "pdf",
    "sample.epub" => "epub",
    "sample.cbz" => "cbz",
    "sample.cbr" => "cbr"
  }.each do |fixture, format|
    it "accepts #{fixture} and detects it as #{format}" do
      book = book_with(fixture)

      expect(book).to be_valid
      expect(book.detected_file_format).to eq(format)
    end
  end

  it "stores the detected format on save" do
    book = book_with("sample.epub")
    book.save!

    expect(book.reload.file_format).to eq("epub")
  end

  it "rejects a non-PDF wearing a .pdf name, even when PDF is declared" do
    book = book_with("fake.pdf", content_type: "application/pdf")

    expect(book).not_to be_valid
    expect(book.errors[:file]).to include("is an unsupported or unreadable file")
  end

  it "rejects a comic archive without the .cbz extension" do
    expect(book_with("sample.cbz", filename: "comic.zip")).not_to be_valid
  end

  it "checks the stored bytes of an already-uploaded blob instead of its declared type" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("fake.pdf").open, filename: "fake.pdf", content_type: "application/pdf", identify: false
    )
    book = build(:book)
    book.file.attach(blob.signed_id)

    expect(book).not_to be_valid
    expect(book.errors[:file]).to include("is an unsupported or unreadable file")
  end

  it "rejects files larger than 500 MB" do
    book = book_with("sample.pdf")
    allow(book.attachment_changes["file"].blob).to receive(:byte_size).and_return(500.megabytes + 1)

    expect(book).not_to be_valid
    expect(book.errors[:file]).to include("must be 500 MB or smaller")
  end
end
