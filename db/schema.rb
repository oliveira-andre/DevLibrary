# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_20_235426) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bookmarks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.string "location", null: false
    t.decimal "progress", precision: 5, scale: 2, default: "0.0", null: false
    t.string "label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_bookmarks_on_book_id"
    t.index ["user_id", "book_id", "location"], name: "index_bookmarks_on_user_id_and_book_id_and_location", unique: true
    t.index ["user_id", "book_id", "progress"], name: "index_bookmarks_on_user_id_and_book_id_and_progress"
    t.check_constraint "progress >= 0::numeric AND progress <= 100::numeric", name: "bookmarks_progress_check"
  end

  create_table "books", force: :cascade do |t|
    t.string "title", null: false
    t.string "authors", default: [], null: false, array: true
    t.string "kind", default: "book", null: false
    t.string "reading_direction", default: "ltr", null: false
    t.string "status", default: "draft", null: false
    t.datetime "published_at"
    t.string "public_id", null: false
    t.string "file_format"
    t.text "search_text", default: "", null: false
    t.decimal "average_rating", precision: 3, scale: 2, default: "0.0", null: false
    t.integer "reviews_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_books_on_public_id", unique: true
    t.index ["search_text"], name: "index_books_on_search_text", opclass: :gin_trgm_ops, using: :gin
    t.index ["status", "average_rating", "reviews_count"], name: "index_books_on_status_and_average_rating_and_reviews_count"
    t.index ["status", "published_at"], name: "index_books_on_status_and_published_at"
    t.index ["status", "title"], name: "index_books_on_status_and_title"
    t.check_constraint "file_format IS NULL OR (file_format::text = ANY (ARRAY['pdf'::character varying, 'epub'::character varying, 'cbz'::character varying, 'cbr'::character varying]::text[]))", name: "books_file_format_check"
    t.check_constraint "kind::text = ANY (ARRAY['book'::character varying, 'comic'::character varying, 'manga'::character varying, 'storybook'::character varying]::text[])", name: "books_kind_check"
    t.check_constraint "reading_direction::text = ANY (ARRAY['ltr'::character varying, 'rtl'::character varying]::text[])", name: "books_reading_direction_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying]::text[])", name: "books_status_check"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_categories_on_lower_name", unique: true
  end

  create_table "categorizations", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "category_id"], name: "index_categorizations_on_book_id_and_category_id", unique: true
    t.index ["category_id"], name: "index_categorizations_on_category_id"
  end

  create_table "conversions", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.bigint "requested_by_id"
    t.string "source_checksum", null: false
    t.string "target_format", null: false
    t.string "status", default: "pending", null: false
    t.text "failure_reason"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "source_checksum", "target_format"], name: "index_conversions_uniqueness", unique: true
    t.index ["requested_by_id"], name: "index_conversions_on_requested_by_id"
    t.index ["status"], name: "index_conversions_on_status"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'processing'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "conversions_status_check"
    t.check_constraint "target_format::text = ANY (ARRAY['pdf'::character varying, 'epub'::character varying]::text[])", name: "conversions_target_format_check"
  end

  create_table "libraries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_libraries_on_user_id", unique: true
  end

  create_table "library_entries", force: :cascade do |t|
    t.bigint "library_id", null: false
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_library_entries_on_book_id"
    t.index ["library_id", "book_id"], name: "index_library_entries_on_library_id_and_book_id", unique: true
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.string "location", null: false
    t.decimal "progress", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_notes_on_book_id"
    t.index ["user_id", "book_id", "progress"], name: "index_notes_on_user_id_and_book_id_and_progress"
    t.check_constraint "progress >= 0::numeric AND progress <= 100::numeric", name: "notes_progress_check"
  end

  create_table "reading_positions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.string "location"
    t.decimal "progress", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "read_at"
    t.string "reading_direction"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_reading_positions_on_book_id"
    t.index ["user_id", "book_id"], name: "index_reading_positions_on_user_id_and_book_id", unique: true
    t.check_constraint "progress >= 0::numeric AND progress <= 100::numeric", name: "reading_positions_progress_check"
    t.check_constraint "reading_direction IS NULL OR (reading_direction::text = ANY (ARRAY['ltr'::character varying, 'rtl'::character varying]::text[]))", name: "reading_positions_direction_check"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.integer "rating", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "created_at"], name: "index_reviews_on_book_id_and_created_at"
    t.index ["user_id", "book_id"], name: "index_reviews_on_user_id_and_book_id", unique: true
    t.check_constraint "rating >= 1 AND rating <= 5", name: "reviews_rating_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shelf_placements", force: :cascade do |t|
    t.bigint "shelf_id", null: false
    t.bigint "library_entry_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["library_entry_id"], name: "index_shelf_placements_on_library_entry_id"
    t.index ["shelf_id", "library_entry_id"], name: "index_shelf_placements_on_shelf_id_and_library_entry_id", unique: true
  end

  create_table "shelves", force: :cascade do |t|
    t.bigint "library_id", null: false
    t.string "name", null: false
    t.string "kind", default: "custom", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "library_id, lower((name)::text)", name: "index_shelves_on_library_id_and_lower_name", unique: true
    t.index ["library_id"], name: "index_shelves_one_favorites_per_library", unique: true, where: "((kind)::text = 'favorites'::text)"
    t.check_constraint "kind::text = ANY (ARRAY['favorites'::character varying, 'custom'::character varying]::text[])", name: "shelves_kind_check"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", default: "", null: false
    t.string "role", default: "reader", null: false
    t.integer "failed_sign_in_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.integer "lockout_count", default: 0, null: false
    t.boolean "reader_page_animation", default: true, null: false
    t.string "reader_theme", default: "light", null: false
    t.integer "reader_text_size", default: 100, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "reader_text_size = ANY (ARRAY[80, 90, 100, 115, 130, 150, 175])", name: "users_reader_text_size_check"
    t.check_constraint "reader_theme::text = ANY (ARRAY['light'::character varying, 'sepia'::character varying, 'dark'::character varying]::text[])", name: "users_reader_theme_check"
    t.check_constraint "role::text = ANY (ARRAY['reader'::character varying, 'admin'::character varying]::text[])", name: "users_role_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bookmarks", "books"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "categorizations", "books"
  add_foreign_key "categorizations", "categories"
  add_foreign_key "conversions", "books"
  add_foreign_key "conversions", "users", column: "requested_by_id"
  add_foreign_key "libraries", "users"
  add_foreign_key "library_entries", "books"
  add_foreign_key "library_entries", "libraries"
  add_foreign_key "notes", "books"
  add_foreign_key "notes", "users"
  add_foreign_key "reading_positions", "books"
  add_foreign_key "reading_positions", "users"
  add_foreign_key "reviews", "books"
  add_foreign_key "reviews", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "shelf_placements", "library_entries"
  add_foreign_key "shelf_placements", "shelves"
  add_foreign_key "shelves", "libraries"
end
