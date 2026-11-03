require "rails_helper"

RSpec.describe Shelf, type: :model do
  let(:library) { create(:user).library }
  let(:favorites) { library.favorites_shelf }

  it { is_expected.to belong_to(:library) }
  it { is_expected.to have_many(:shelf_placements).dependent(:destroy) }

  it "requires a name of at most 50 characters" do
    expect(library.shelves.build(name: "")).not_to be_valid
    expect(library.shelves.build(name: "a" * 51)).not_to be_valid
    expect(library.shelves.build(name: "a" * 50)).to be_valid
  end

  it "is unique per library regardless of case" do
    library.shelves.create!(name: "Manga")

    expect(library.shelves.build(name: "manga")).not_to be_valid
    expect(create(:user).library.shelves.build(name: "Manga")).to be_valid
  end

  it "reserves the Favorites name in any casing" do
    shelf = library.shelves.build(name: "FAVORITES")

    expect(shelf).not_to be_valid
    expect(shelf.errors[:name]).to include("is reserved")
  end

  it "keeps emoji in shelf names" do
    expect(library.shelves.create!(name: "Cozy reads ☕📚").reload.name).to eq("Cozy reads ☕📚")
  end

  describe "the Favorites shelf" do
    it "cannot be renamed" do
      expect(favorites.update(name: "Loved")).to be(false)
      expect(favorites.errors[:name]).to include("can't be changed for Favorites")
    end

    it "cannot be destroyed directly" do
      expect(favorites.destroy).to be(false)
      expect(Shelf.exists?(favorites.id)).to be(true)
    end

    it "goes away with its account" do
      user = library.user

      expect { user.destroy! }.not_to raise_error
      expect(Shelf.exists?(favorites.id)).to be(false)
    end

    it "is the only one of its kind in a library" do
      expect { library.shelves.insert!({ name: "Second", kind: "favorites", created_at: Time.current, updated_at: Time.current }) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it "keeps its books in the library when a custom shelf is destroyed" do
    book = create(:book, :published)
    shelf = library.shelves.create!(name: "Temp")
    library.place!(book, shelf: shelf)

    shelf.destroy!

    expect(library.books).to include(book)
  end
end
