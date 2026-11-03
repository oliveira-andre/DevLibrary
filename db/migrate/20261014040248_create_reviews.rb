class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :book, null: false, foreign_key: true, index: false
      t.integer :rating, null: false

      t.timestamps

      t.check_constraint "rating BETWEEN 1 AND 5", name: "reviews_rating_check"
    end

    add_index :reviews, [ :user_id, :book_id ], unique: true
    add_index :reviews, [ :book_id, :created_at ]
  end
end
