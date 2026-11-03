class CreateLibraryEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :library_entries do |t|
      t.references :library, null: false, foreign_key: true, index: false
      t.references :book, null: false, foreign_key: true

      t.timestamps
    end

    add_index :library_entries, [ :library_id, :book_id ], unique: true
  end
end
