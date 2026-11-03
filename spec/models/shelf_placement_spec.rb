require "rails_helper"

RSpec.describe ShelfPlacement, type: :model do
  let(:library) { create(:user).library }
  let(:shelf) { library.shelves.create!(name: "Mine") }
  let(:entry) { library.add!(create(:book, :published)) }

  it "is unique per shelf and entry" do
    shelf.shelf_placements.create!(library_entry: entry)

    expect(shelf.shelf_placements.build(library_entry: entry)).not_to be_valid
  end

  it "requires the shelf and the entry to share a library" do
    foreign_entry = create(:user).library.add!(create(:book, :published))
    placement = shelf.shelf_placements.build(library_entry: foreign_entry)

    expect(placement).not_to be_valid
    expect(placement.errors[:library_entry]).to include("must belong to the same library as the shelf")
  end

  it "touches the shelf and the entry" do
    shelf
    entry
    travel 1.minute do
      expect { shelf.shelf_placements.create!(library_entry: entry) }
        .to change { shelf.reload.updated_at }.and change { entry.reload.updated_at }
    end
  end
end
