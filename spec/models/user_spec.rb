require "rails_helper"

RSpec.describe User, type: :model do
  describe "email address" do
    it "is stored trimmed and lowercased" do
      user = create(:user, email_address: " Ana@Example.COM ")

      expect(user.reload.email_address).to eq("ana@example.com")
    end

    it "is matched regardless of case and surrounding spaces" do
      user = create(:user, email_address: "ana@example.com")

      expect(User.find_by(email_address: "ANA@example.com ")).to eq(user)
    end

    it "is unique regardless of case" do
      create(:user, email_address: "ana@example.com")
      duplicate = build(:user, email_address: "Ana@Example.com")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email_address]).to include("has already been taken")
    end

    it "must be well-formed" do
      expect(build(:user, email_address: "not-an-email")).not_to be_valid
    end
  end

  describe "password" do
    it "rejects fewer than 8 characters" do
      user = build(:user, password: "short12", password_confirmation: "short12")

      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too short (minimum is 8 characters)")
    end

    it "accepts 8 and 72 characters" do
      expect(build(:user, password: "a" * 8, password_confirmation: "a" * 8)).to be_valid
      expect(build(:user, password: "a" * 72, password_confirmation: "a" * 72)).to be_valid
    end

    it "rejects more than 72 characters" do
      expect(build(:user, password: "a" * 73, password_confirmation: "a" * 73)).not_to be_valid
    end
  end

  describe "name" do
    it "defaults to an empty string" do
      expect(User.new.name).to eq("")
    end

    it "is required when signing up" do
      user = build(:user, name: "")

      expect(user.save(context: [ :create, :sign_up ])).to be(false)
      expect(user.errors[:name]).to include("can't be blank")
    end

    it "is optional for accounts created outside sign-up" do
      expect(build(:user, name: "").save).to be(true)
    end

    it "can be added later to a nameless account" do
      user = create(:user, name: "")

      expect(user.update(name: "Ana")).to be(true)
    end

    it "cannot be cleared once set" do
      user = create(:user, name: "Ana")

      expect(user.update(name: "  ")).to be(false)
      expect(user.errors[:name]).to include("can't be blank")
    end

    it "is at most 100 characters" do
      expect(build(:user, name: "a" * 100)).to be_valid
      expect(build(:user, name: "a" * 101)).not_to be_valid
    end

    it "is stripped" do
      expect(create(:user, name: "  Ana  ").name).to eq("Ana")
    end

    it "keeps emoji intact" do
      expect(create(:user, name: "Ana 📚👩🏽‍💻").reload.name).to eq("Ana 📚👩🏽‍💻")
    end
  end

  describe "role" do
    it "defaults to reader" do
      user = create(:user)

      expect(user.role).to eq("reader")
      expect(user).to be_reader
      expect(user).not_to be_admin
    end

    it "can be admin" do
      expect(build(:user, role: "admin")).to be_admin
    end

    it "rejects unknown roles with a validation error" do
      user = build(:user, role: "owner")

      expect(user).not_to be_valid
      expect(user.errors[:role]).to include("is not included in the list")
    end
  end

  it { is_expected.to have_many(:sessions).dependent(:destroy) }
  it { is_expected.to have_one(:library).dependent(:destroy) }

  it "gets an empty library with a Favorites shelf when created" do
    library = create(:user).library

    expect(library.entries).to be_empty
    expect(library.shelves.pluck(:name, :kind)).to eq([ [ "Favorites", "favorites" ] ])
  end
end
