require "rails_helper"

RSpec.describe Conversion, type: :model do
  let(:requester) { create(:user) }
  let(:epub_book) { create(:book, :published, :epub) }

  def request(book: epub_book, format: "pdf", user: requester)
    Conversion.request!(book: book, target_format: format, user: user)
  end

  it { is_expected.to belong_to(:book) }
  it { is_expected.to belong_to(:requested_by).class_name("User").optional }

  describe ".request!" do
    it "records a pending conversion of the current file version" do
      conversion = request

      expect(conversion).to be_pending
      expect(conversion.source_checksum).to eq(epub_book.file.blob.checksum)
      expect(conversion.requested_by).to eq(requester)
    end

    it "returns the same conversion to everyone who asks" do
      first = request
      second = request(user: create(:user))

      expect(second).to eq(first)
      expect(second.requested_by).to eq(requester)
      expect(Conversion.count).to eq(1)
    end

    it "refuses to convert a book to its own format" do
      expect { request(format: "epub") }.to raise_error(ActiveRecord::RecordInvalid, /Target format/)
    end

    it "only converts to PDF or EPUB" do
      expect { request(format: "mobi") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "retries a failed conversion, keeping the last failure reason" do
      conversion = request
      conversion.start!
      conversion.fail!("boom")

      retried = request

      expect(retried).to eq(conversion)
      expect(retried).to be_pending
      expect(retried.attempts).to eq(1)
      expect(retried.failure_reason).to eq("boom")
    end
  end

  describe "status transitions" do
    let(:conversion) { request }

    it "moves through processing to completed, clearing the failure reason" do
      conversion.start!
      expect(conversion).to be_processing

      conversion.fail!("boom")
      conversion.retry!
      conversion.start!
      conversion.complete!(io: file_fixture("sample.pdf").open, filename: "converted.pdf")

      expect(conversion.reload).to be_completed
      expect(conversion.output).to be_attached
      expect(conversion.failure_reason).to be_nil
    end

    it "cannot be completed without an output file" do
      conversion.status = "completed"

      expect(conversion).not_to be_valid
      expect(conversion.errors[:output]).to include("can't be blank")
    end

    it "bumps the book on every status change" do
      conversion
      travel 1.minute do
        expect { conversion.start! }.to change { epub_book.reload.updated_at }
      end
    end
  end

  it "discards conversions of the old file when the book's file is replaced" do
    old = request
    epub_book.file.attach(io: file_fixture("manga.cbz").open, filename: "replacement.cbz")
    epub_book.save!

    expect(Conversion.exists?(old.id)).to be(false)
  end

  it "keeps conversions when the book changes but its file does not" do
    old = request

    epub_book.update!(title: "New title")

    expect(Conversion.exists?(old.id)).to be(true)
  end

  it "forgets the requester when their account is deleted" do
    conversion = request

    requester.destroy!

    expect(conversion.reload.requested_by_id).to be_nil
  end

  describe "Book#convertible_to?" do
    it "is false for the book's own format and true for the other one" do
      pdf_book = create(:book, :published)

      expect(pdf_book.convertible_to?(:pdf)).to be(false)
      expect(pdf_book.convertible_to?(:epub)).to be(true)
      expect(epub_book.convertible_to?("pdf")).to be(true)
      expect(epub_book.convertible_to?(:mobi)).to be(false)
    end
  end
end
