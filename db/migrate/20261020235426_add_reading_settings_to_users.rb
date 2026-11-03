# Reading settings saved on the account (002 data-model.md, research R7): page-turn
# animation, reader theme and text size, applied to every book on every device.
class AddReadingSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.boolean :reader_page_animation, null: false, default: true
      t.string :reader_theme, null: false, default: "light"
      t.integer :reader_text_size, null: false, default: 100
    end

    add_check_constraint :users, "reader_theme IN ('light','sepia','dark')", name: "users_reader_theme_check"
    add_check_constraint :users, "reader_text_size IN (80,90,100,115,130,150,175)", name: "users_reader_text_size_check"
  end
end
