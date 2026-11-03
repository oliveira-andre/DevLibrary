class CreateShelves < ActiveRecord::Migration[8.1]
  def change
    create_table :shelves do |t|
      t.references :library, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :kind, null: false, default: "custom"

      t.timestamps

      t.check_constraint "kind IN ('favorites','custom')", name: "shelves_kind_check"
    end

    add_index :shelves, "library_id, lower(name)", unique: true, name: "index_shelves_on_library_id_and_lower_name"
    add_index :shelves, :library_id, unique: true, where: "kind = 'favorites'", name: "index_shelves_one_favorites_per_library"
  end
end
