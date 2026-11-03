require "rails_helper"

RSpec.describe SearchNormalizable, type: :model do
  describe ".normalize" do
    it "strips accents from Latin letters and lowercases" do
      expect(described_class.normalize("Café Noir")).to eq("cafe noir")
    end

    it "trims surrounding whitespace" do
      expect(described_class.normalize("  ÉCOLE  ")).to eq("ecole")
    end

    it "handles several accented words" do
      expect(described_class.normalize("naïve résumé")).to eq("naive resume")
    end

    it "keeps Japanese kana dakuten intact" do
      expect(described_class.normalize("バカ")).to eq("バカ")
    end

    it "leaves katakana without marks unchanged" do
      expect(described_class.normalize("ナルト")).to eq("ナルト")
    end

    it "returns an empty string for nil" do
      expect(described_class.normalize(nil)).to eq("")
    end

    it "squishes internal whitespace" do
      expect(described_class.normalize("dark    fantasy\n saga")).to eq("dark fantasy saga")
    end
  end
end
