require "rails_helper"

RSpec.describe User::ReadingSettings, type: :model do
  let(:user) { create(:user) }

  it "animates page turns, uses the light theme and medium text by default" do
    expect(user.reader_page_animation).to be(true)
    expect(user.reader_theme).to eq("light")
    expect(user.reader_text_size).to eq(100)
  end

  describe "validation" do
    it "accepts only the light, sepia and dark themes" do
      %w[light sepia dark].each do |theme|
        expect(build(:user, reader_theme: theme)).to be_valid
      end

      invalid = build(:user, reader_theme: "neon")
      expect(invalid).not_to be_valid
      expect(invalid.errors[:reader_theme]).to be_present
    end

    it "accepts only the seven text sizes" do
      User::ReadingSettings::TEXT_SIZES.each do |size|
        expect(build(:user, reader_text_size: size)).to be_valid
      end

      expect(build(:user, reader_text_size: 95)).not_to be_valid
    end

    it "requires the animation setting to be on or off" do
      expect(build(:user, reader_page_animation: nil)).not_to be_valid
    end
  end

  describe "#reading_settings" do
    it "returns the three settings the reader renders from" do
      user.update!(reader_page_animation: false, reader_theme: "sepia", reader_text_size: 130)

      expect(user.reading_settings).to eq(page_animation: false, theme: "sepia", text_size: 130)
    end
  end

  describe "#update_reading_settings" do
    it "saves the three settings" do
      expect(user.update_reading_settings(reader_page_animation: "0", reader_theme: "dark", reader_text_size: "150")).to be(true)

      expect(user.reload.reading_settings).to eq(page_animation: false, theme: "dark", text_size: 150)
    end

    it "ignores anything that is not a reading setting" do
      user.update_reading_settings(reader_theme: "dark", role: "admin", name: "")

      expect(user.reload).to have_attributes(reader_theme: "dark", role: "reader")
      expect(user.name).to be_present
    end

    it "returns false with errors for an invalid value" do
      expect(user.update_reading_settings(reader_theme: "neon")).to be(false)
      expect(user.errors[:reader_theme]).to be_present
      expect(user.reload.reader_theme).to eq("light")
    end

    it "changes the user's cache version, so per-user caches move on" do
      expect { user.update_reading_settings(reader_text_size: 115) }.to change { user.reload.cache_key_with_version }
    end
  end
end
