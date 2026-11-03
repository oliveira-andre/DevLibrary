class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :book, null: false, foreign_key: true
      t.string :location, null: false
      t.decimal :progress, precision: 5, scale: 2, null: false, default: 0

      t.timestamps

      t.check_constraint "progress BETWEEN 0 AND 100", name: "notes_progress_check"
    end

    add_index :notes, [ :user_id, :book_id, :progress ]
  end
end
