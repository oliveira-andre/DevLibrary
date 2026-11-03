class AddProfileAndLockoutToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :name, null: false, default: ""
      t.string :role, null: false, default: "reader"
      t.integer :failed_sign_in_attempts, null: false, default: 0
      t.datetime :locked_until
      t.integer :lockout_count, null: false, default: 0
    end

    add_check_constraint :users, "role IN ('reader','admin')", name: "users_role_check"
  end
end
