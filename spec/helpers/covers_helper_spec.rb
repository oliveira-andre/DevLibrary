require "rails_helper"

RSpec.describe CoversHelper, type: :helper do
  let(:book) { create(:book, :published, :with_cover, title: "Café Noir") }

  describe "#cover_image_tag" do
    it "renders the card variant lazily, at its CSS size, with the title as alt text" do
      html = helper.cover_image_tag(book)

      expect(html).to include('alt="Café Noir"', 'width="240"', 'height="360"', 'loading="lazy"', 'class="cover"')
      expect(html).to include("/rails/active_storage/representations/redirect/")
    end

    it "renders the large variant at book-page size" do
      expect(helper.cover_image_tag(book, variant: :large)).to include('width="300"', 'height="450"')
    end

    it "shows a title placeholder when the book has no cover" do
      html = helper.cover_image_tag(create(:book, :published, title: "No Cover Yet"))

      expect(html).to include("cover-placeholder", "No Cover Yet")
      expect(html).not_to include("<img")
    end
  end

  describe "#cover_url" do
    it "keeps the same URL within the hour, so browsers can cache the image" do
      travel_to(Time.zone.local(2026, 10, 20, 14, 5)) { @first = helper.cover_url(book, :card) }
      travel_to(Time.zone.local(2026, 10, 20, 14, 55)) { @second = helper.cover_url(book, :card) }

      expect(@second).to eq(@first)
    end

    it "moves to a new URL in the next hour" do
      travel_to(Time.zone.local(2026, 10, 20, 14, 55)) { @first = helper.cover_url(book, :card) }
      travel_to(Time.zone.local(2026, 10, 20, 15, 5)) { @second = helper.cover_url(book, :card) }

      expect(@second).not_to eq(@first)
    end

    it "stays valid for at least an hour after it is generated" do
      url = travel_to(Time.zone.local(2026, 10, 20, 14, 59)) { helper.cover_url(book, :card) }
      signed_id = url[%r{/redirect/([^/]+)/}, 1]

      travel_to(Time.zone.local(2026, 10, 20, 15, 58)) do
        expect(ActiveStorage::Blob.find_signed(signed_id)).to eq(book.cover.blob)
      end
    end
  end
end
