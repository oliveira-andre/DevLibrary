class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :title, null: false
      t.string :authors, array: true, null: false, default: []
      t.string :kind, null: false, default: "book"
      t.string :reading_direction, null: false, default: "ltr"
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.string :public_id, null: false
      t.string :file_format
      t.text :search_text, null: false, default: ""
      t.decimal :average_rating, precision: 3, scale: 2, null: false, default: 0
      t.integer :reviews_count, null: false, default: 0

      t.timestamps

      t.check_constraint "kind IN ('book','comic','manga','storybook')", name: "books_kind_check"
      t.check_constraint "reading_direction IN ('ltr','rtl')", name: "books_reading_direction_check"
      t.check_constraint "status IN ('draft','published','archived')", name: "books_status_check"
      t.check_constraint "file_format IS NULL OR file_format IN ('pdf','epub','cbz','cbr')", name: "books_file_format_check"
    end

    add_index :books, :public_id, unique: true
    add_index :books, :search_text, using: :gin, opclass: :gin_trgm_ops
    add_index :books, [ :status, :published_at ]
    add_index :books, [ :status, :average_rating, :reviews_count ]
    add_index :books, [ :status, :title ]
  end
end
