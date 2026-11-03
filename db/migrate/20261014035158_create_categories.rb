class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :categories, "lower(name)", unique: true, name: "index_categories_on_lower_name"
  end
end
