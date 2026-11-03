class CreateShelfPlacements < ActiveRecord::Migration[8.1]
  def change
    create_table :shelf_placements do |t|
      t.references :shelf, null: false, foreign_key: true, index: false
      t.references :library_entry, null: false, foreign_key: true

      t.timestamps
    end

    add_index :shelf_placements, [ :shelf_id, :library_entry_id ], unique: true
  end
end
