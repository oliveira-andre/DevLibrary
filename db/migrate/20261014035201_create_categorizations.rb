class CreateCategorizations < ActiveRecord::Migration[8.1]
  def change
    create_table :categorizations do |t|
      t.references :book, null: false, foreign_key: true, index: false
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end

    add_index :categorizations, [ :book_id, :category_id ], unique: true
  end
end
