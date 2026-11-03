class CreateConversions < ActiveRecord::Migration[8.1]
  def change
    create_table :conversions do |t|
      t.references :book, null: false, foreign_key: true, index: false
      t.references :requested_by, null: true, foreign_key: { to_table: :users }
      t.string :source_checksum, null: false
      t.string :target_format, null: false
      t.string :status, null: false, default: "pending"
      t.text :failure_reason
      t.integer :attempts, null: false, default: 0

      t.timestamps

      t.check_constraint "target_format IN ('pdf','epub')", name: "conversions_target_format_check"
      t.check_constraint "status IN ('pending','processing','completed','failed')", name: "conversions_status_check"
    end

    add_index :conversions, [ :book_id, :source_checksum, :target_format ], unique: true, name: "index_conversions_uniqueness"
    add_index :conversions, :status
  end
end
