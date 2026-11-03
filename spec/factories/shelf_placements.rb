FactoryBot.define do
  factory :shelf_placement do
    shelf
    library_entry { association(:library_entry, library: shelf.library) }
  end
end
