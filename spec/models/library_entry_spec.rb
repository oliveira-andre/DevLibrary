require "rails_helper"

RSpec.describe LibraryEntry, type: :model do
  let(:user) { create(:user) }
  let(:library) { user.library }
  let(:book) { create(:book, :published) }

  it { is_expected.to belong_to(:library) }
  it { is_expected.to belong_to(:book) }
  it { is_expected.to have_many(:shelf_placements).dependent(:destroy) }

  it "is unique per library and book" do
    library.entries.create!(book: book)

    expect(library.entries.build(book: book)).not_to be_valid
  end

  it "requires a published book when created" do
    entry = library.entries.build(book: create(:book))

    expect(entry).not_to be_valid
    expect(entry.errors[:book]).to include("must be published")
  end

  it "destroys its shelf placements with it" do
    entry = library.entries.create!(book: book)
    library.shelves.create!(name: "Mine").shelf_placements.create!(library_entry: entry)

    expect { entry.destroy! }.to change(ShelfPlacement, :count).by(-1)
  end

  it "touches the library and the user" do
    user
    travel 1.minute do
      expect { library.entries.create!(book: book) }
        .to change { library.reload.updated_at }.and change { user.reload.updated_at }
    end
  end
end
