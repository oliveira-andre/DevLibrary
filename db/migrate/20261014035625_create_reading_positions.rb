class CreateReadingPositions < ActiveRecord::Migration[8.1]
  def change
    create_table :reading_positions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :book, null: false, foreign_key: true
      t.string :location
      t.decimal :progress, precision: 5, scale: 2, null: false, default: 0
      t.datetime :read_at
      t.string :reading_direction

      t.timestamps

      t.check_constraint "reading_direction IS NULL OR reading_direction IN ('ltr','rtl')", name: "reading_positions_direction_check"
      t.check_constraint "progress BETWEEN 0 AND 100", name: "reading_positions_progress_check"
    end

    add_index :reading_positions, [ :user_id, :book_id ], unique: true
  end
end
