---

description: "Task list for the Core Data Model feature"
---

# Tasks: Core Data Model

**Input**: Design documents from `specs/001-core-data-model/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: **REQUIRED.** Constitution Principle II (NON-NEGOTIABLE) overrides the template
default. Every story writes its RSpec examples first, and they must fail before
implementation starts. Every cached read has a hit test and an invalidation test
(Principle IX), tagged `:caching`.

**Organization**: Tasks are grouped by user story (US1–US9 from spec.md) so each can be
implemented and tested on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: Which user story the task belongs to (US1–US9)
- Paths are repo-relative. Migrations are created with `bin/rails g migration <Name>` and
  land at `db/migrate/<timestamp>_<name>.rb`. Generate them in task order so timestamps
  follow dependency order.

## Conventions used by every model task

- Enums are **string-backed**: `enum :x, { a: "a", ... }, validate: true`, plus a database
  `CHECK` constraint in the migration (research R5).
- Foreign keys: `t.references :x, null: false, foreign_key: true` with **no**
  `on_delete: :cascade`. Deletion uses `dependent: :destroy` (R13).
- Cached reads use `Rails.cache.fetch` with the exact keys from the cache table in
  [data-model.md](data-model.md).
- Factories go in `spec/factories/<plural>.rb` and use FFaker for text.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Framework installs and test tooling every story uses

- [X] T001 Run `bin/rails action_text:install` and keep the generated
  `db/migrate/*_create_action_text_tables.action_text.rb`, importmap pins in
  `config/importmap.rb`, `app/javascript/application.js` imports and
  `app/assets/stylesheets/actiontext.css`. Keep Trix as the installed editor (the editor
  choice is deferred, research R1). Run `bin/rails db:migrate` and confirm
  `action_text_rich_texts` exists in `db/schema.rb`.
- [X] T002 Create migration `EnablePgTrgm` in `db/migrate/*_enable_pg_trgm.rb` containing
  `enable_extension "pg_trgm"`. Migrate and confirm `enable_extension "pg_trgm"` appears in
  `db/schema.rb`.
- [X] T003 [P] Create `spec/support/caching.rb`: an `around(:each, :caching)` hook that
  replaces `Rails.cache` with `ActiveSupport::Cache::MemoryStore.new` for the example
  (stub `Rails.cache` with `allow(Rails).to receive(:cache)`) and restores it afterward.
  The test environment keeps `config.cache_store = :null_store` in
  `config/environments/test.rb`.
- [X] T004 [P] Create `spec/support/query_counter.rb`: a helper `count_queries { ... }`
  that subscribes to `"sql.active_record"` and counts events, excluding names `"SCHEMA"`
  and `"TRANSACTION"` and payloads with `cached: true`. Include it in all specs through
  `RSpec.configure`.
- [X] T005 [P] Create `spec/support/system_viewports.rb`: register Capybara drivers
  `:chrome_mobile` (headless Chrome, window 390×844) and `:chrome_desktop` (headless
  Chrome, window 1440×900). Add a `before(:each, type: :system)` hook that calls
  `driven_by` based on example metadata `viewport: :mobile | :desktop` (default
  `:desktop`). Add a helper `on_each_viewport(&block)` that defines the given examples
  twice, mobile first, then desktop. Remove the empty `before(:each, type: :system)`
  block in `spec/rails_helper.rb`.
- [X] T006 [P] Create `spec/support/authentication_helpers.rb` with `sign_in_as(user,
  password: "password123")`. For request specs it posts to `session_path` with
  `email_address`/`password`. Add a system-spec variant that fills the sign-in form at
  `new_session_path`. Include each in the matching spec type.
- [X] T007 [P] Create `script/generate_spec_fixtures.rb`, a plain Ruby script (stdlib only,
  shelling out to the `zip` CLI) that writes these files into `spec/fixtures/files/`:
  - `sample.pdf`: a minimal valid one-page PDF beginning with `%PDF-1.4`
  - `sample.epub`: a minimal reflowable EPUB with an uncompressed `mimetype` entry first,
    so bytes 30–57 read `mimetypeapplication/epub+zip`, plus `META-INF/container.xml`,
    an OPF and one XHTML chapter
  - `sample.cbz` and `manga.cbz`: ZIP files, each with two tiny PNG pages
  - `sample.cbr`: a file starting with the RAR signature `Rar!\x1A\x07\x00` followed by
    padding
  - `fake.pdf`: a ZIP or DOCX-like archive renamed to `.pdf`
  - `cover.jpg`, `cover.png`, `cover.webp`, `cover.gif`: 1×1 images written from base64
    literals

  Run it and commit the generated files.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared helpers, the security baseline and the root route that every story
relies on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T008 [P] Write `spec/models/concerns/search_normalizable_spec.rb` for
  `SearchNormalizable.normalize("…")`:
  - `"Café Noir"` → `"cafe noir"`
  - `"  ÉCOLE  "` → `"ecole"`
  - `"naïve résumé"` → `"naive resume"`
  - `"バカ"` stays `"バカ"` (kana dakuten preserved)
  - `"ナルト"` unchanged
  - `nil` → `""`
  - internal whitespace squished
- [X] T009 Implement `app/models/concerns/search_normalizable.rb` (module with
  `module_function def normalize(text)`): `text.to_s.unicode_normalize(:nfd)`, then
  `gsub(/(\p{Latin})\p{Mn}+/, '\1')`, `unicode_normalize(:nfc)`, `downcase`, `squish`
  (research R4). Make T008 pass.
- [X] T010 [P] Create `spec/factories/users.rb` with sequence `email_address`
  (`"user#{n}@example.com"`), `password { "password123" }` and
  `password_confirmation { "password123" }`.
- [X] T011 [P] Write `spec/requests/active_storage_access_spec.rb`. Create a blob with
  `ActiveStorage::Blob.create_and_upload!(io: file_fixture("cover.png").open,
  filename: "cover.png")`. Then:
  - `GET rails_blob_path(blob)` while signed out → 302 to `new_session_path`
  - after `sign_in_as(user)` → 302 to a service URL (not the sign-in page)

  This covers [contracts/sign-in.md](contracts/sign-in.md), "Active Storage routes".
- [X] T012 In `app/controllers/concerns/authentication.rb` change `request_authentication`
  to `redirect_to main_app.new_session_path` (the engine-safe route helper, research R3).
  Create `config/initializers/active_storage_authentication.rb` with
  `Rails.application.config.to_prepare { ActiveStorage::BaseController.include
  Authentication }`. Make T011 pass.
- [X] T013 [P] In `config/application.rb` add
  `config.active_storage.urls_expire_in = 1.hour` (research R3).
- [X] T014 In `config/routes.rb` add `get "home", to: "home#show", as: :home` and
  `root "home#show"`. Create `app/controllers/home_controller.rb` (inherits sign-in
  enforcement from `ApplicationController`) with a blank `app/views/home/show.html.erb`,
  which the search feature will build. Point `after_authentication_url` in
  `app/controllers/concerns/authentication.rb` at `home_url`, and cover it in
  `spec/requests/home_spec.rb` ([contracts/sign-in.md](contracts/sign-in.md), "Home
  route"). *(Changed at the user's request: the root is not the sign-in page.)*

**Checkpoint**: Foundation ready. `bundle exec rspec` is green, and story work can begin.

---

## Phase 3: User Story 1 - Accounts that resist password guessing (Priority: P1) 🎯 MVP

**Goal**: Accounts with normalized email, name, role and per-account lockout that works
across rotating IPs. The sign-in and reset flows follow
[contracts/sign-in.md](contracts/sign-in.md).

**Independent Test**: Run `bundle exec rspec spec/models/user_spec.rb
spec/models/user/lockable_spec.rb spec/requests/sessions_spec.rb
spec/requests/passwords_spec.rb spec/system/sign_in_lockout_spec.rb`. Acceptance
scenarios 1–8 pass. Scenario 9 (library created with the account) is verified in US3.

### Tests for User Story 1 ⚠️ (write first, must fail)

- [X] T015 [P] [US1] Write `spec/models/user_spec.rb`:
  - email stored as `"ana@example.com"` from `" Ana@Example.COM "`
  - `find_by(email_address: "ANA@example.com ")` finds it
  - uniqueness ignores case
  - an invalid format is rejected
  - password shorter than 8 rejected; 8 and 72 accepted
  - `name` defaults to `""`; a blank name is invalid in context `[:create, :sign_up]` and
    valid in a plain `save`
  - a non-blank name cannot be updated to `""`; name > 100 characters invalid; name
    stripped
  - `role` defaults to `"reader"`; `role: "owner"` gives a validation error (not
    `ArgumentError`); `admin?`/`reader?` predicates
  - shoulda: `have_many(:sessions)`
- [X] T016 [P] [US1] Write `spec/models/user/lockable_spec.rb` (use `travel_to`):
  - 4 failures → `failed_sign_in_attempts == 4`, not locked
  - the 5th failure → `locked_until ≈ now + 15.minutes`, `lockout_count == 1`, attempts
    reset to 0
  - after expiry, 5 more failures → 30 minutes, then 60; the cap is 24 hours (simulate
    `lockout_count: 10`)
  - attempts while locked leave all three counters unchanged
  - `register_successful_sign_in!` and a password change (`update!(password:,
    password_confirmation:)`) both reset all counters and `locked_until`
  - `User.authenticate_with_lockout` returns `nil` for an unknown email, a wrong password
    and a locked account with the correct password, and still calls `authenticate` on the
    locked user (`expect(user).to receive(:authenticate)` via `allow(User).to
    receive(:find_by)`); it returns the user on success
- [X] T017 [P] [US1] Write `spec/requests/sessions_spec.rb` covering every row of the
  `POST /session` table in [contracts/sign-in.md](contracts/sign-in.md):
  - unknown email, wrong password and locked account each produce an identical redirect
    location and flash alert `"Try another email address or password."`
  - success with `"  ANA@example.com "` → redirect to `root_url`
  - 5 failures sent with 5 different `REMOTE_ADDR` values lock the account
  - more than 10 requests from one IP in 3 minutes → alert `"Try again later."`
    (clear `Rails.cache`/rate-limit store between examples)
- [X] T018 [P] [US1] Write `spec/requests/passwords_spec.rb`:
  - a valid reset token plus a new valid password → notice `"Password has been reset."`
    and the user is no longer `locked?`
  - a new password `"short"` → redirect to the edit page with an alert containing the
    length error message

  Generate the token with `user.password_reset_token`.
- [X] T019 [P] [US1] Write `spec/system/sign_in_lockout_spec.rb` using
  `on_each_viewport` (mobile 390×844 first, then desktop 1440×900):
  - enter a wrong password 5 times, then the correct one; every attempt shows
    "Try another email address or password." and the user is not signed in
  - a fresh unlocked user signing in with `"  USER@example.com "` succeeds

### Implementation for User Story 1

- [X] T020 [US1] Create migration `AddProfileAndLockoutToUsers`
  (`db/migrate/*_add_profile_and_lockout_to_users.rb`):
  - `name` string, null: false, default `""`
  - `role` string, null: false, default `"reader"`, plus
    `add_check_constraint :users, "role IN ('reader','admin')", name: "users_role_check"`
  - `failed_sign_in_attempts` integer, null: false, default `0`
  - `locked_until` datetime, null: true
  - `lockout_count` integer, null: false, default `0`

  Migrate.
- [X] T021 [US1] Extend `app/models/user.rb`:
  - `enum :role, { reader: "reader", admin: "admin" }, validate: true`
  - `normalizes :name, with: ->(n) { n.strip }`
  - `validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: true`
  - `validates :password, length: { in: 8..72 }, allow_nil: true`
  - `validates :name, length: { maximum: 100 }`
  - `validates :name, presence: true, on: :sign_up`
  - a `validate :name_not_cleared, on: :update` method that adds an error when
    `name_was.present? && name.blank?`
  - `include User::Lockable`

  Make T015 pass.
- [X] T022 [US1] Create `app/models/user/lockable.rb` (concern) with constants
  `MAX_FAILED_ATTEMPTS = 5`, `BASE_LOCK = 15.minutes`, `MAX_LOCK = 24.hours`, and:
  - `locked?` → `locked_until.present? && locked_until.future?`
  - `register_failed_sign_in!`: inside `with_lock`, no-op if `locked?`; otherwise increment
    attempts, and at 5 set `locked_until = Time.current + [BASE_LOCK * 2**lockout_count,
    MAX_LOCK].min`, increment `lockout_count` and reset attempts, using `update_columns`
  - `register_successful_sign_in!` and `clear_sign_in_lockout!`: `update_columns` all three
    counters to zero/nil
  - `after_update :clear_sign_in_lockout!, if: :saved_change_to_password_digest?`
  - `class_methods { def authenticate_with_lockout(email_address:, password:) }`: find by
    the normalized email. If the user is locked, call `user.authenticate(password)`,
    discard the result and return `nil`. If unknown, return
    `authenticate_by(email_address:, password:)`, which is constant-time and returns nil.
    On a wrong password call `register_failed_sign_in!` and return `nil`. On success call
    `register_successful_sign_in!` and return the user.

  Make T016 pass (research R6).
- [X] T023 [US1] Update `SessionsController#create` in
  `app/controllers/sessions_controller.rb` to call
  `User.authenticate_with_lockout(email_address: params[:email_address], password:
  params[:password])`. Keep the existing `rate_limit` line and the existing failure
  redirect and alert verbatim for every failure path. Make T017 pass.
- [X] T024 [US1] Update `PasswordsController#update` in
  `app/controllers/passwords_controller.rb` to redirect with
  `alert: @user.errors.full_messages.to_sentence` on failure instead of the fixed
  "Passwords did not match.". Make T018 pass.
- [X] T025 [US1] Update `spec/factories/users.rb`: add `name { FFaker::Name.name }` and
  traits `:admin` (`role { "admin" }`), `:nameless` (`name { "" }`) and `:locked`
  (`locked_until { 10.minutes.from_now }`, `lockout_count { 1 }`). Run T019 and make it
  pass on both viewports.

**Checkpoint**: Sign-in hardening works on its own. US1 specs are green.

---

## Phase 4: User Story 2 - Admin-curated catalog (Priority: P1)

**Goal**: Books, categories and their links, with byte-verified files, status lifecycle,
reading-direction defaults and a stable public id.

**Independent Test**: Run `bundle exec rspec spec/validators spec/models/category_spec.rb
spec/models/categorization_spec.rb spec/models/book_spec.rb`. US2 acceptance scenarios 1–4
and 6–8 pass. Scenario 5 (readers refused) is enforced by the admin screens; this story
provides the `admin?` predicate.

### Tests for User Story 2 ⚠️ (write first, must fail)

- [X] T026 [P] [US2] Write `spec/validators/book_file_validator_spec.rb` using a throwaway
  model or `Book`:
  - accepts `sample.pdf` (`file_format == "pdf"`), `sample.epub` (`"epub"`), `sample.cbz`
    (`"cbz"`) and `sample.cbr` (`"cbr"`)
  - rejects `fake.pdf` with the message "is an unsupported or unreadable file", even when
    `content_type: "application/pdf"` is declared
  - rejects a file whose blob `byte_size` exceeds `500.megabytes` (stub `byte_size`)
- [X] T027 [P] [US2] Write `spec/validators/cover_image_validator_spec.rb`: accepts
  `cover.jpg`, `cover.png` and `cover.webp`; rejects `cover.gif` and `sample.pdf` renamed
  `x.png`; rejects more than `10.megabytes`.
- [X] T028 [P] [US2] Write `spec/models/category_spec.rb`:
  - name presence; length ≤ 50; `"  Dark   Fantasy "` squished
  - `"fantasy"` rejected when `"Fantasy"` exists
  - shoulda `have_many(:books).through(:categorizations)`
  - renaming touches every linked book's `updated_at`
  - destroying a category leaves its books intact
- [X] T029 [P] [US2] Write `spec/models/categorization_spec.rb`: a duplicate
  `(book, category)` is invalid; creating or destroying one bumps both `book.updated_at`
  and `category.updated_at`.
- [X] T030 [P] [US2] Write `spec/models/book_spec.rb`:
  - title presence and ≤ 255
  - `authors` defaults to `[]`
  - `kind` defaults to `"book"`; `kind: "magazine"` gives a validation error; `kind_manga?`
    exists
  - a new manga with no direction gets `"rtl"`; a new comic gets `"ltr"`; an admin can set
    a manga to `"ltr"` explicitly
  - changing `kind` book→manga without touching the direction sets `"rtl"`
  - `status` defaults to `"draft"`
  - `publish!` without a file raises `ActiveRecord::RecordInvalid`; `publish!` with
    `sample.pdf` sets `published_at` once (a republish after `archive!` keeps the original
    `published_at`)
  - `public_id` is 12 base58 characters and unchanged after a title update;
    `to_param == public_id`
  - `search_text == "cafe noir jose saramago"` for title "Café Noir" and authors
    ["José Saramago"]
  - `visible_to(admin)` includes drafts; `visible_to(reader)` returns published only
  - description rich text round-trips `"Great 🤯 👨‍👩‍👧 🇧🇷"` intact
  - `Book.catalog_version` changes after a create, an update and a destroy
  - destroying a book destroys its categorizations

### Implementation for User Story 2

- [X] T031 [P] [US2] Create migration `CreateCategories` (`db/migrate/*_create_categories.rb`):
  `name` string, null: false; timestamps;
  `add_index :categories, "lower(name)", unique: true, name: "index_categories_on_lower_name"`.
- [X] T032 [US2] Create migration `CreateBooks` (`db/migrate/*_create_books.rb`):
  - `title` string, null: false
  - `authors` string, array: true, null: false, default `[]`
  - `kind` string, null: false, default `"book"`
  - `reading_direction` string, null: false, default `"ltr"`
  - `status` string, null: false, default `"draft"`
  - `published_at` datetime
  - `public_id` string, null: false
  - `file_format` string, null: true
  - `search_text` text, null: false, default `""`
  - `average_rating` decimal precision 3 scale 2, null: false, default `0`
  - `reviews_count` integer, null: false, default `0`
  - timestamps

  Check constraints:
  - `kind IN ('book','comic','manga','storybook')`
  - `reading_direction IN ('ltr','rtl')`
  - `status IN ('draft','published','archived')`
  - `file_format IS NULL OR file_format IN ('pdf','epub','cbz','cbr')`

  Indexes:
  - unique `public_id`
  - `add_index :books, :search_text, using: :gin, opclass: :gin_trgm_ops`
  - `[:status, :published_at]`
  - `[:status, :average_rating, :reviews_count]`
  - `[:status, :title]`
- [X] T033 [US2] Create migration `CreateCategorizations`
  (`db/migrate/*_create_categorizations.rb`): `t.references :book` and
  `t.references :category` (null: false, foreign_key: true), timestamps, unique index
  `[:book_id, :category_id]`. Migrate all three.
- [X] T034 [P] [US2] Implement `app/validators/book_file_validator.rb`
  (`ActiveModel::EachValidator`, used as `validates :file, book_file: true`):
  - read the first 4,096 bytes from the pending attachable
    (`record.attachment_changes["file"]&.attachable`: an IO, an uploaded file, or a hash
    with `io:`) or from `blob.open` when already stored
  - identify with `Marcel::MimeType.for(StringIO.new(head))`, magic only: no `name:`, no
    `declared_type:`
  - map: `application/pdf` → `pdf`; ZIP with `head[30, 28] == "mimetypeapplication/epub+zip"`
    → `epub`; ZIP with a `.cbz` filename → `cbz`; RAR signature with a `.cbr` filename →
    `cbr`; anything else → error `"is an unsupported or unreadable file"`
  - add an error when `byte_size > 500.megabytes`
  - store the detected value with `record.detected_file_format = ...`

  Make T026 pass (research R2).
- [X] T035 [P] [US2] Implement `app/validators/cover_image_validator.rb` the same way:
  magic-only Marcel detection, allowing only `image/jpeg`, `image/png` and `image/webp`;
  error `"must be a JPEG, PNG or WebP image"`; size ≤ `10.megabytes`. Make T027 pass.
- [X] T036 [P] [US2] Implement `app/models/category.rb`:
  - `has_many :categorizations, dependent: :destroy`
  - `has_many :books, through: :categorizations`
  - `normalizes :name, with: ->(n) { n.squish }`
  - `validates :name, presence: true, length: { maximum: 50 }, uniqueness: { case_sensitive: false }`
  - `after_save -> { books.touch_all }, if: :saved_change_to_name?`

  Make T028 pass.
- [X] T037 [P] [US2] Implement `app/models/categorization.rb`: `belongs_to :book, touch:
  true`, `belongs_to :category, touch: true`, and `validates :category_id, uniqueness: {
  scope: :book_id }`. Make T029 pass.
- [X] T038 [US2] Implement `app/models/book.rb`:
  - `include SearchNormalizable`
  - `has_rich_text :description`, `has_one_attached :cover`, `has_one_attached :file`
  - `has_many :categorizations, dependent: :destroy` and
    `has_many :categories, through: :categorizations`
  - enums:
    - `enum :kind, { book: "book", comic: "comic", manga: "manga", storybook: "storybook" }, prefix: true, validate: true`
    - `enum :reading_direction, { ltr: "ltr", rtl: "rtl" }, validate: true`
    - `enum :status, { draft: "draft", published: "published", archived: "archived" }, validate: true`
  - `attr_accessor :detected_file_format`
  - validations:
    - `validates :title, presence: true, length: { maximum: 255 }`
    - `validates :file, book_file: true`
    - `validates :file, presence: { message: "is required to publish" }, if: :published?`
    - `validates :cover, cover_image: true`
  - `before_validation`: assign the reading-direction default on create, or when
    `kind_changed? && !reading_direction_changed?` (`kind_manga?` → `"rtl"`, else `"ltr"`)
  - `before_validation :assign_public_id, on: :create`: `SecureRandom.base58(12)`, looping
    until `Book.exists?(public_id:)` is false
  - `before_save`:
    - `search_text = SearchNormalizable.normalize([title, *authors].join(" "))`
    - `file_format = detected_file_format if detected_file_format`
    - `published_at ||= Time.current if status_changed? && published?`
  - `to_param` → `public_id`
  - `publish!` / `archive!` / `unpublish!` → `update!(status: ...)`
  - `scope :visible_to, ->(user) { user.admin? ? all : published }`
  - `def self.catalog_version = "#{count}-#{maximum(:updated_at)&.to_fs(:usec)}"`

  Make T030 pass (data-model "books").
- [X] T039 [P] [US2] Create `spec/factories/categories.rb` (sequence names) and
  `spec/factories/books.rb` with these traits:
  - `:with_file` (attach `sample.pdf`), `:epub` (attach `sample.epub`)
  - `:manga` (`kind { "manga" }`, attach `manga.cbz`)
  - `:with_cover` (attach `cover.png`)
  - `:published` (with_file + `status { "published" }`), `:archived`
  - `authors { [FFaker::Name.name] }`

**Checkpoint**: The catalog layer works on its own. US2 specs are green.

---

## Phase 5: User Story 3 - Personal library, shelves and favorites (Priority: P1)

**Goal**: One private library per user with a built-in Favorites shelf, custom shelves,
idempotent add/remove and favorite toggles, and a cached search inside the library.

**Independent Test**: Run `bundle exec rspec spec/models/library_spec.rb
spec/models/library_entry_spec.rb spec/models/shelf_spec.rb
spec/models/shelf_placement_spec.rb` plus the US3 examples in `spec/models/user_spec.rb`
and `spec/models/book_spec.rb`. US3 scenarios 1–9 and US1 scenario 9 pass.

**Depends on**: US2 (books).

### Tests for User Story 3 ⚠️ (write first, must fail)

- [X] T040 [P] [US3] Write `spec/models/library_spec.rb`:
  - a new user gets exactly one library whose shelves are `["Favorites"]` (kind
    `favorites`)
  - `add!(published_book)` twice → one entry
  - `add!(draft_book)` raises `RecordInvalid`
  - `favorite!` on a book not in the library → entry plus Favorites placement;
    `unfavorite!` → placement gone, entry stays
  - `favorited?`
  - `place!(book, shelf:)` adds to the library when needed; `unplace!`
  - `remove!` deletes the entry and all its placements (Favorites included), while the
    book, a `ReadingPosition` row created with `ReadingPosition.create!`, and that user's
    notes and bookmarks remain (create these after US4/US5, or mark the examples
    `pending` until then)
  - `search(query: "cafe")` and `search(shelf:)` return only this user's matching entries,
    ordered by last read, then `created_at` desc
  - `:caching` tag: a second `search` call runs 0 queries (`count_queries`), and adding a
    book, placing it on a shelf, or updating a book title changes the result
- [X] T041 [P] [US3] Write `spec/models/library_entry_spec.rb`: unique per
  `(library, book)`; the book must be published on create; destroying it destroys its
  placements; creating one bumps `library.updated_at` and `user.updated_at`.
- [X] T042 [P] [US3] Write `spec/models/shelf_spec.rb`:
  - name presence and ≤ 50
  - `"manga"` rejected when `"Manga"` exists in the same library but allowed in another
    user's library
  - a custom shelf named `"favorites"` (any casing) rejected
  - the Favorites shelf cannot be renamed (error) or destroyed (`destroy` returns false)
  - destroying a user destroys Favorites without error
  - a second `kind: "favorites"` shelf in a library raises `ActiveRecord::RecordNotUnique`
  - destroying a custom shelf keeps its entries in the library
- [X] T043 [P] [US3] Write `spec/models/shelf_placement_spec.rb`: unique per
  `(shelf, library_entry)`; invalid when the shelf and entry belong to different
  libraries; creating one touches the shelf and the entry.
- [X] T044 [P] [US3] Add to `spec/models/book_spec.rb`: `Book.visible_to(reader)` includes
  an archived book only when it is in that reader's library.

### Implementation for User Story 3

- [X] T045 [US3] Create migration `CreateLibraries` (`db/migrate/*_create_libraries.rb`):
  `t.references :user, null: false, foreign_key: true, index: { unique: true }`,
  timestamps.
- [X] T046 [US3] Create migration `CreateLibraryEntries`
  (`db/migrate/*_create_library_entries.rb`): `t.references :library` and
  `t.references :book` (null: false, foreign_key: true), timestamps, unique index
  `[:library_id, :book_id]`.
- [X] T047 [US3] Create migration `CreateShelves` (`db/migrate/*_create_shelves.rb`):
  - `t.references :library` (null: false, foreign_key: true)
  - `name` string, null: false
  - `kind` string, null: false, default `"custom"`
  - timestamps
  - check constraint `kind IN ('favorites','custom')`
  - `add_index :shelves, "library_id, lower(name)", unique: true`
  - `add_index :shelves, :library_id, unique: true, where: "kind = 'favorites'",
    name: "index_shelves_one_favorites_per_library"`
- [X] T048 [US3] Create migration `CreateShelfPlacements`
  (`db/migrate/*_create_shelf_placements.rb`): `t.references :shelf` and
  `t.references :library_entry` (null: false, foreign_key: true), timestamps, unique index
  `[:shelf_id, :library_entry_id]`. Migrate.
- [X] T049 [P] [US3] Implement `app/models/library_entry.rb`:
  - `belongs_to :library, touch: true`
  - `belongs_to :book`
  - `has_many :shelf_placements, dependent: :destroy`
  - `has_many :shelves, through: :shelf_placements`
  - `validates :book_id, uniqueness: { scope: :library_id }`
  - `validate :book_must_be_published, on: :create`
- [X] T050 [P] [US3] Implement `app/models/shelf.rb`:
  - `belongs_to :library, touch: true`
  - `has_many :shelf_placements, dependent: :destroy`
  - `has_many :entries, through: :shelf_placements, source: :library_entry`
  - `enum :kind, { favorites: "favorites", custom: "custom" }, prefix: true, validate: true`
  - `normalizes :name, with: ->(n) { n.squish }`
  - `validates :name, presence: true, length: { maximum: 50 }, uniqueness: { scope: :library_id, case_sensitive: false }`
  - `validate :name_not_reserved, if: :kind_custom?`: `name.casecmp?("favorites")` → error
  - `validate :favorites_not_renamed, on: :update`
  - `before_destroy` → `throw :abort if kind_favorites? && !destroyed_by_association`
- [X] T051 [P] [US3] Implement `app/models/shelf_placement.rb`: `belongs_to :shelf,
  touch: true`, `belongs_to :library_entry, touch: true`, uniqueness of
  `library_entry_id` scoped to `shelf_id`, and `validate :same_library`.
- [X] T052 [US3] Implement `app/models/library.rb`:
  - associations:
    - `belongs_to :user, touch: true`
    - `has_many :entries, class_name: "LibraryEntry", dependent: :destroy`
    - `has_many :books, through: :entries`
    - `has_many :shelves, dependent: :destroy`
    - `has_one :favorites_shelf, -> { kind_favorites }, class_name: "Shelf"`
  - `after_create { shelves.create!(name: "Favorites", kind: "favorites") }`
  - domain methods per [contracts/domain-api.md](contracts/domain-api.md), each wrapped
    in a transaction:
    - `add!` → `entries.create_or_find_by!(book:)`
    - `remove!`, `favorite!`, `unfavorite!`, `favorited?`, `place!`, `unplace!`
  - `search(query: nil, shelf: nil)`:
    - cached at `[user.cache_key_with_version, "library", Book.catalog_version,
      SearchNormalizable.normalize(query), shelf&.id]`
    - filters on `books.search_text LIKE` for each term
    - returns entries `includes(book: { cover_attachment: :blob })`, ordered by the
      user's `reading_positions.read_at` desc nulls last, then `library_entries.created_at`
      desc
- [X] T053 [US3] In `app/models/user.rb` add `has_one :library, dependent: :destroy` and
  `after_create :create_library!`. Add a US1 acceptance-9 example to
  `spec/models/user_spec.rb` (a new user has a library with Favorites).
- [X] T054 [US3] In `app/models/book.rb` add `has_many :library_entries,
  dependent: :destroy`. Change `visible_to` so readers see `published` OR (`archived` AND
  `id IN` the user's library book ids). Make T044 pass.
- [X] T055 [P] [US3] Create `spec/factories/libraries.rb`,
  `spec/factories/library_entries.rb`, `spec/factories/shelves.rb` and
  `spec/factories/shelf_placements.rb`. Libraries come from `user.library`, so the entry
  and shelf factories default to `library { association(:user).library }`. Make
  T040–T043 pass.

**Checkpoint**: The library layer works with US2. US3 specs are green.

---

## Phase 6: User Story 4 - Resume exactly where you stopped (Priority: P1)

**Goal**: Newest-wins reading positions that are independent of library membership, a
per-user direction override, and private bookmarks.

**Independent Test**: Run `bundle exec rspec spec/models/reading_position_spec.rb
spec/models/bookmark_spec.rb`. US4 scenarios 1–5 pass.

**Depends on**: US2 (books).

### Tests for User Story 4 ⚠️ (write first, must fail)

- [X] T056 [P] [US4] Write `spec/models/reading_position_spec.rb`:
  - `record!(location: "42", progress: 30, read_at: t)` creates a row; a second call with
    `read_at: t - 4.minutes` leaves location `"42"`
  - a newer call updates it
  - `read_at: 2.hours.from_now` is stored as ≈ `Time.current`
  - works for a book not in the user's library
  - survives `library.remove!(book)`
  - progress outside 0..100 is invalid
  - unique per `(user, book)`
  - `effective_reading_direction` returns the book's direction until
    `set_direction!(direction: "ltr")` is called on a manga, then `"ltr"`; `nil` clears it
  - `reading_direction: "up"` is invalid
  - writing bumps `user.updated_at` but not `book.updated_at`
  - `:caching`: `ReadingPosition.for(user:, book:)` runs 0 queries on repeat and reflects
    a newer `record!`
- [X] T057 [P] [US4] Write `spec/models/bookmark_spec.rb`:
  - location presence
  - a duplicate `(user, book, location)` is invalid
  - label ≤ 100
  - progress 0..100
  - another user's bookmarks never appear in `Bookmark.for(user:, book:)`
  - `for` returns rows in progress order
  - `:caching`: hit runs 0 queries; creating a bookmark changes the result

### Implementation for User Story 4

- [X] T058 [US4] Create migration `CreateReadingPositions`
  (`db/migrate/*_create_reading_positions.rb`):
  - `t.references :user` and `t.references :book` (null: false, foreign_key: true)
  - `location` string, null: true
  - `progress` decimal precision 5 scale 2, null: false, default `0`
  - `read_at` datetime, null: true
  - `reading_direction` string, null: true
  - timestamps
  - unique index `[:user_id, :book_id]`
  - check constraints `reading_direction IS NULL OR reading_direction IN ('ltr','rtl')`
    and `progress BETWEEN 0 AND 100`
- [X] T059 [US4] Create migration `CreateBookmarks` (`db/migrate/*_create_bookmarks.rb`):
  - `t.references :user` and `t.references :book` (null: false, foreign_key: true)
  - `location` string, null: false
  - `progress` decimal precision 5 scale 2, null: false, default `0`
  - `label` string, null: true
  - timestamps
  - unique index `[:user_id, :book_id, :location]`
  - index `[:user_id, :book_id, :progress]`

  Migrate.
- [X] T060 [P] [US4] Implement `app/models/reading_position.rb`:
  - `belongs_to :user, touch: true`, `belongs_to :book`
  - `enum :reading_direction, { ltr: "ltr", rtl: "rtl" }, prefix: :override, validate: { allow_nil: true }`
  - `validates :progress, numericality: { in: 0..100 }`
  - `self.record!(user:, book:, location:, progress:, read_at:)`:
    - clamp `read_at` to `Time.current` when it is more than 1 minute in the future
    - `create_or_find_by!(user:, book:)`, then `with_lock`
    - update `location`/`progress`/`read_at` only when the stored `read_at` is nil or older
    - return the record
  - `self.set_direction!(user:, book:, direction:)`
  - `self.for(user:, book:)`: cached at
    `[user.cache_key_with_version, "reading_position", book.id]`
  - `effective_reading_direction` → `reading_direction || book.reading_direction`

  Make T056 pass (research R8).
- [X] T061 [P] [US4] Implement `app/models/bookmark.rb`:
  - `belongs_to :user, touch: true`, `belongs_to :book`
  - `validates :location, presence: true, uniqueness: { scope: [:user_id, :book_id] }`
  - `validates :label, length: { maximum: 100 }`
  - `validates :progress, numericality: { in: 0..100 }`
  - `scope :in_book_order, -> { order(:progress, :created_at) }`
  - `self.for(user:, book:)`: cached at `[user.cache_key_with_version, "bookmarks",
    book.id]`, returning `user.bookmarks.where(book:).in_book_order.to_a`

  Make T057 pass.
- [X] T062 [US4] Add `has_many :reading_positions, dependent: :destroy` and
  `has_many :bookmarks, dependent: :destroy` to both `app/models/user.rb` and
  `app/models/book.rb`. Create `spec/factories/reading_positions.rb` and
  `spec/factories/bookmarks.rb`. Un-pend the related T040 examples.

**Checkpoint**: Resume and bookmarks work. US4 specs are green.

---

## Phase 7: User Story 5 - Private reading notes (Priority: P2)

**Goal**: Rich-text notes with emoji, anchored to a position, private to their author,
listed in book order.

**Independent Test**: Run `bundle exec rspec spec/models/note_spec.rb`. US5 scenarios 1–4
pass.

**Depends on**: US2 (books) and T001 (Action Text).

### Tests for User Story 5 ⚠️ (write first, must fail)

- [X] T063 [P] [US5] Write `spec/models/note_spec.rb`:
  - content `"Great twist 🤯"` round-trips with the emoji intact
  - empty or whitespace-only content (`"<div> </div>"`) is invalid
  - plain text over 10,000 characters is invalid
  - location presence; progress 0..100
  - `Note.for(user:, book:)` returns notes at progress 30, 5 and 12 in the order 5, 12, 30
    and never includes another user's notes
  - editing the content bumps `user.updated_at` (through the RichText → note → user
    touch chain)
  - destroying the book destroys its notes
  - `:caching`: hit runs 0 queries; editing a note changes the result

### Implementation for User Story 5

- [X] T064 [US5] Create migration `CreateNotes` (`db/migrate/*_create_notes.rb`):
  `t.references :user` and `t.references :book` (null: false, foreign_key: true),
  `location` string, null: false, `progress` decimal precision 5 scale 2, null: false,
  default `0`, timestamps, index `[:user_id, :book_id, :progress]`. Migrate.
- [X] T065 [US5] Implement `app/models/note.rb`:
  - `belongs_to :user, touch: true`, `belongs_to :book`
  - `has_rich_text :content`
  - `validates :location, presence: true`
  - `validates :progress, numericality: { in: 0..100 }`
  - `validate :content_present_and_within_limit`: `content.to_plain_text.strip`
    present and ≤ 10,000 characters
  - `scope :in_book_order, -> { order(:progress, :created_at) }`
  - `self.for(user:, book:)`: cached at `[user.cache_key_with_version, "notes", book.id]`
- [X] T066 [US5] Add `has_many :notes, dependent: :destroy` to `app/models/user.rb` and
  `app/models/book.rb`. Create `spec/factories/notes.rb`. Make T063 pass and un-pend the
  related T040 example.

**Checkpoint**: Notes work. US5 specs are green.

---

## Phase 8: User Story 6 - Reviews and ratings (Priority: P2)

**Goal**: One review per user per published book, with an integer rating 1–5, required
rich-text content, and an always-accurate average and count.

**Independent Test**: Run `bundle exec rspec spec/models/review_spec.rb`. US6 scenarios
1–4 and 6 pass. Scenario 5 (admin removes any review) is enforced by the review screens
using `admin?`; this story only ensures `destroy` updates the averages.

**Depends on**: US2 (books) and T001 (Action Text).

### Tests for User Story 6 ⚠️ (write first, must fail)

- [X] T067 [P] [US6] Write `spec/models/review_spec.rb`:
  - ratings `0`, `6`, `"3.5"` and `nil` are invalid; `1` and `5` are valid
  - blank content is invalid; content over 5,000 plain-text characters is invalid
  - a second review by the same user on the same book is invalid
  - a review on a draft book is invalid
  - reviews of 4 and 2 → `average_rating == 3.0` and `reviews_count == 2`
  - updating 2 → 5 gives 4.5; destroying one gives the remaining value; destroying all
    gives 0 and 0
  - destroying the book does not call `refresh_rating!` (expect it to not have been
    received)
  - renaming the reviewer bumps the book's `updated_at`
  - `:caching`: `Review.for_book(book, page: 1)` runs 0 queries on repeat and reflects a
    new review and a reviewer rename

### Implementation for User Story 6

- [X] T068 [US6] Create migration `CreateReviews` (`db/migrate/*_create_reviews.rb`):
  - `t.references :user` and `t.references :book` (null: false, foreign_key: true)
  - `rating` integer, null: false
  - timestamps
  - check constraint `rating BETWEEN 1 AND 5`
  - unique index `[:user_id, :book_id]`
  - index `[:book_id, :created_at]`

  Migrate.
- [X] T069 [US6] Implement `app/models/review.rb`:
  - `belongs_to :user`, `belongs_to :book`
  - `has_rich_text :content`
  - `validates :rating, numericality: { only_integer: true, in: 1..5 }`
  - `validates :user_id, uniqueness: { scope: :book_id }`
  - `validate :book_must_be_published, on: :create`
  - `validate :content_present_and_within_limit` (≤ 5,000 plain-text characters)
  - `after_save :refresh_book_rating`
  - `after_destroy :refresh_book_rating, unless: -> { destroyed_by_association&.active_record == Book }`
  - `self.for_book(book, page:, per: 20)`: cached at
    `["book", book.cache_key_with_version, "reviews", page]`, preloading the user and the
    rich text content, newest first
- [X] T070 [US6] In `app/models/book.rb` add `has_many :reviews, dependent: :destroy` and
  `refresh_rating!`: one aggregate query, `reviews.pick(Arel.sql("COALESCE(AVG(rating),0),
  COUNT(*)"))`, then `update_columns(average_rating:, reviews_count:, updated_at:
  Time.current)`.
- [X] T071 [US6] In `app/models/user.rb` add `has_many :reviews, dependent: :destroy` and
  `after_save -> { Book.where(id: reviews.select(:book_id)).touch_all }, if:
  :saved_change_to_name?`. Create `spec/factories/reviews.rb`. Make T067 pass.

**Checkpoint**: Reviews and averages work. US6 specs are green.

---

## Phase 9: User Story 7 - Search with category and sort (Priority: P2)

**Goal**: A cached catalog query (text plus one category plus sort) behind the upcoming
search page, and a cached category list for its dropdown.

**Independent Test**: Run `bundle exec rspec spec/models/book/search_spec.rb
spec/models/category_spec.rb`. US7 scenarios 1–5 pass.

**Depends on**: US2 (books and categories).

### Tests for User Story 7 ⚠️ (write first, must fail)

- [X] T072 [P] [US7] Write `spec/models/book/search_spec.rb`:
  - `"cafe"` finds "Café Noir"; `"CAF"` finds it (partial word)
  - `"noir cafe"` finds it (every term must match, in any order)
  - matches on author names
  - drafts and archived books are never returned
  - `category:` filters to one category; `nil` returns all
  - sorts:
    - `newest` orders by `published_at` desc and is the default without a query
    - `relevance` is the default with a query and ranks the exact title above a partial
      match
    - `relevance` without a query falls back to `newest`
    - `title_asc` / `title_desc`
    - `top_rated` orders by `average_rating` desc, then `reviews_count` desc (set the
      columns directly)
  - `per: 24` paging returns the second page correctly
  - `%` and `_` in the query are matched literally
  - `:caching`: repeat call runs 0 queries; publishing a new matching book, renaming a
    category, or changing a book's categories changes the result
- [X] T073 [P] [US7] Add to `spec/models/category_spec.rb`: `Category.cached_ordered`
  returns categories sorted by name; `:caching` hit runs 0 queries; a create or rename
  changes the result.

### Implementation for User Story 7

- [X] T074 [US7] Implement `app/models/book/search.rb` (`class Book::Search`) with
  `SORTS = %w[relevance newest title_asc title_desc top_rated]` and
  `initialize(query:, category:, sort:, page:, per:)`:
  - normalize the query with `SearchNormalizable.normalize`
  - split it into terms, each a `where("books.search_text LIKE ?",
    "%#{Book.sanitize_sql_like(term)}%")`
  - scope to `Book.published`, joining `categorizations` when a category is given
  - relevance order: `Arel.sql(Book.sanitize_sql_array(["word_similarity(?,
    books.search_text) DESC, books.title ASC", q]))`
  - `results` → `Rails.cache.fetch(["catalog/search", Book.catalog_version, q,
    category&.id, sort, page, per]) { scope.with_attached_cover.limit(per).offset((page -
    1) * per).to_a }`

  Unknown sorts fall back to the default (research R4).
- [X] T075 [US7] In `app/models/book.rb` add
  `def self.search(query: nil, category: nil, sort: nil, page: 1, per: 24) =
  Book::Search.new(...).results`. In `app/models/category.rb` add
  `self.cached_ordered`: `Rails.cache.fetch(["categories",
  order(:name).cache_key_with_version]) { order(:name).to_a }`. Make T072 and T073 pass.

**Checkpoint**: The search query layer is ready for the search page feature.

---

## Phase 10: User Story 8 - Download and convert (Priority: P3)

**Goal**: Conversion records (PDF/EPUB only) that are idempotent per file version, with a
status machine, retry, and purging of stale conversions when the file is replaced.

**Independent Test**: Run `bundle exec rspec spec/models/conversion_spec.rb`. US8
scenarios 1–5 pass.

**Depends on**: US2 (books).

### Tests for User Story 8 ⚠️ (write first, must fail)

- [X] T076 [P] [US8] Write `spec/models/conversion_spec.rb`:
  - `request!(book: epub_book, target_format: "pdf", user:)` creates a `pending` row with
    `source_checksum == epub_book.file.blob.checksum`; a second request by another user
    returns the same row, and `requested_by` stays the first user
  - `target_format: "epub"` on an EPUB raises `RecordInvalid`; `"mobi"` is invalid
  - `start!` → `processing`
  - `fail!("boom")` → `failed` with `failure_reason == "boom"`; `request!` again →
    `pending`, `attempts == 1`, reason kept
  - `complete!(io: file_fixture("sample.pdf").open, filename: "x.pdf")` → `completed`,
    output attached, reason cleared
  - `completed` without an output is invalid
  - replacing the book's file with different bytes destroys the old conversions
  - destroying the requesting user nullifies `requested_by_id`
  - status changes bump `book.updated_at`
  - `book.convertible_to?(:pdf)` is false for a PDF book and true for an EPUB book

### Implementation for User Story 8

- [X] T077 [US8] Create migration `CreateConversions` (`db/migrate/*_create_conversions.rb`):
  - `t.references :book` (null: false, foreign_key: true)
  - `t.references :requested_by` (null: true, `foreign_key: { to_table: :users }`)
  - `source_checksum` string, null: false
  - `target_format` string, null: false
  - `status` string, null: false, default `"pending"`
  - `failure_reason` text, null: true
  - `attempts` integer, null: false, default `0`
  - timestamps
  - check constraints `target_format IN ('pdf','epub')` and
    `status IN ('pending','processing','completed','failed')`
  - unique index `[:book_id, :source_checksum, :target_format]`
  - index `:status`

  Migrate.
- [X] T078 [US8] Implement `app/models/conversion.rb`:
  - `belongs_to :book, touch: true`
  - `belongs_to :requested_by, class_name: "User", optional: true`
  - `has_one_attached :output`
  - `enum :target_format, { pdf: "pdf", epub: "epub" }, prefix: :to, validate: true`
  - `enum :status, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }, validate: true`
  - validations: `target_format` differs from `book.file_format`; the book file is
    attached; `output` is attached when `completed?`
  - `self.request!(book:, target_format:, user:)`: `create_or_find_by!(book:,
    source_checksum: book.current_file_checksum, target_format:) { |c| c.requested_by =
    user }`, then `retry!` if `failed?`
  - transitions:
    - `start!` → `update!(status: :processing)`
    - `complete!(io:, filename:)` → attach and `update!(status: :completed,
      failure_reason: nil)`
    - `fail!(reason)` → `update!(status: :failed, failure_reason: reason)`
    - `retry!` → `update!(status: :pending, attempts: attempts + 1)`

  This follows the data-model state machine.
- [X] T079 [US8] In `app/models/book.rb` add:
  - `has_many :conversions, dependent: :destroy`
  - `current_file_checksum` → `file.blob&.checksum`
  - `convertible_to?(format)` → `%w[pdf epub].include?(format.to_s) && format.to_s !=
    file_format`
  - `after_save :discard_stale_conversions, if: -> { attachment_changes["file"].present? }`:
    `conversions.where.not(source_checksum: current_file_checksum).destroy_all`
- [X] T080 [US8] In `app/models/user.rb` add `has_many :requested_conversions,
  class_name: "Conversion", foreign_key: :requested_by_id, dependent: :nullify`. Create
  `spec/factories/conversions.rb`. Make T076 pass.

**Checkpoint**: The conversion data layer is ready for the conversion engine feature.

---

## Phase 11: User Story 9 - Share a book (Priority: P3)

**Goal**: Share links resolve through the stable `public_id` to the catalog book (never a
library), respect visibility, and return a signed-out recipient to the link after
sign-in.

**Independent Test**: Run `bundle exec rspec spec/models/book_spec.rb
spec/requests/return_after_sign_in_spec.rb`. US9 scenarios 1–3 pass at the model and
request level. The book page itself is a later feature.

**Depends on**: US2 (public_id) and US3 (archived visibility).

### Tests for User Story 9 ⚠️ (write first, must fail)

- [X] T081 [P] [US9] Add to `spec/models/book_spec.rb`:
  - `Book.find_visible!(public_id, user: reader)` returns a published book and raises
    `ActiveRecord::RecordNotFound` for a draft or a destroyed book
  - an archived book is returned only when it is in the reader's library
  - an admin finds drafts
  - `book.to_param` contains no library or shelf data
- [X] T082 [P] [US9] Write `spec/requests/return_after_sign_in_spec.rb`: a signed-out
  `GET` to a protected URL (use `rails_blob_path(blob)` from T011) redirects to
  `new_session_path`. After `POST session_path` with valid credentials, the response
  redirects back to that original URL (FR-054, using the existing
  `return_to_after_authenticating`).

### Implementation for User Story 9

- [X] T083 [US9] In `app/models/book.rb` add
  `def self.find_visible!(public_id, user:) = visible_to(user).find_by!(public_id:)`. Make
  T081 and T082 pass. Fix `Authentication#after_authentication_url` only if T082 fails.

**Checkpoint**: All nine stories are complete at the data layer.

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: Seeds, performance proof, quality gates and live verification

- [X] T084 [P] Write `db/seeds.rb` (idempotent with `find_or_create_by!`):
  - an admin `admin@devlibrary.test` and readers `reader@devlibrary.test` and
    `reader2@devlibrary.test`, all with password `"password123"` and names
  - categories "Fantasy" and "Romance"
  - published books: a PDF (`sample.pdf`), an EPUB "Café Noir" by "José Saramago"
    (`sample.epub`), and a manga (`manga.cbz`, kind `manga`), each with a cover and
    categories

  Run `bin/rails db:seed` twice without errors.
- [X] T085 [P] Write `script/benchmark_search.rb` (run with `bin/rails runner`): insert
  10,000 published books with `insert_all` (precomputed `search_text`, random
  ratings/dates) inside a transaction that it rolls back. Time 200 random
  `Book::Search.new(...)` scope executions with the cache bypassed and print the p95. It
  must be under 1 second (SC-007).
- [X] T086 [P] Create `specs/001-core-data-model/fr-coverage.md` (outside `checklists/`, so the implement gate does not treat it as a review checklist) mapping each
  FR-001…FR-056 to the spec file and example that proves it. FRs enforced by later screen
  features (FR-020 and FR-046 controller authorization, FR-034 display, FR-048 download
  endpoint) are marked "deferred to <feature>" with the predicate or data that supports
  them (SC-009).
- [X] T087 Run `bin/rubocop -a` and `bin/brakeman --no-pager`. Fix every offense and
  warning in files touched by this feature.
- [X] T088 Run `bundle exec rspec` over `spec/` (full suite, including `--tag caching`)
  with 0 failures and 0 pending.
- [X] T089 Run the [quickstart.md](quickstart.md) §1–§3 and §5 validations against the
  development database and confirm every expected outcome.
- [X] T090 Live verification with Playwright MCP per [quickstart.md](quickstart.md) §4,
  **mobile 390×844 first, then desktop 1440×900**: the lockout after 5 wrong passwords,
  identical alerts, signed-out Active Storage access redirecting to sign-in, and
  mixed-case email sign-in. Record the results in the PR description.

  **Result (2026-10-14): passed with Playwright MCP** against `bin/rails server`, mobile
  390×844 first, then desktop 1440×900. Each lockout step was cross-checked on the server
  (request log and user counters):

  | Check | Mobile | Desktop |
  |---|---|---|
  | Signed-out `/home` → sign-in | ✅ | ✅ |
  | Signed-out Active Storage URL → sign-in | ✅ | ✅ |
  | 5 wrong passwords → generic alert, account locked ~15 min | ✅ | ✅ |
  | Correct password while locked → refused, same alert, no session | ✅ | ✅ |
  | Unknown email → identical response | ✅ | ✅ |
  | Mixed-case `ADMIN@DevLibrary.test` → `/home` | ✅ | ✅ |

  Screenshots: `.playwright-mcp/{mobile,desktop}-locked-correct-password.png` (git-ignored).

  **Automation note (not an app bug):** after about 7 rapid submissions in one tab, Chrome
  stopped delivering Playwright's mouse and keyboard input to that tab. No `click` or
  `keydown` reached even a document capture listener, while `requestSubmit()` from JS
  still worked. A fresh tab worked at once, on both viewports. The likely cause is browser
  UI (e.g. the leaked-password warning for the seed password `password123`) holding the
  tab's input. The Selenium system spec's repeated submissions are unaffected.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none. T001 and T002 run first (migrations); T003–T007 are parallel.
- **Foundational (Phase 2)**: depends on Setup and **blocks all stories**.
- **US1 (Phase 3)**: depends only on Foundational.
- **US2 (Phase 4)**: depends only on Foundational. It can run in parallel with US1.
- **US3, US4, US5, US6, US7, US8**: each depends on US2. They are independent of each
  other, except T040's "remove keeps notes/bookmarks" examples, which un-pend in T062 and
  T066.
- **US9**: depends on US2 and US3.
- **Polish (Phase 12)**: depends on all stories.

```text
Setup ─▶ Foundational ─┬─▶ US1
                       └─▶ US2 ─┬─▶ US3 ─▶ US9
                                ├─▶ US4
                                ├─▶ US5
                                ├─▶ US6
                                ├─▶ US7
                                └─▶ US8
                                         all ─▶ Polish
```

### Within Each User Story

- Tests are written first and must fail.
- Migrations come next, in listed order, so timestamps respect foreign keys.
- Then models, then cross-model wiring (associations added to `user.rb`/`book.rb`), then
  factories.
- `app/models/book.rb` and `app/models/user.rb` are edited by several stories. Those tasks
  carry no [P] and must not run concurrently with another story's edit of the same file.

### Parallel Opportunities

- Setup: T003, T004, T005, T006, T007
- Foundational: T008, T010, T011, T013
- US1 tests: T015–T019
- US2 tests: T026–T030; implementation T031, T034, T035, T036, T037, T039
- US3 tests: T040–T044; implementation T049, T050, T051, T055
- US4 tests: T056, T057; implementation T060, T061
- After US2: US4, US5, US6, US7 and US8 can proceed in parallel by different developers,
  coordinating on `book.rb`/`user.rb` edits.

## Parallel Example: User Story 2

```bash
# Tests together:
Task: "Write spec/validators/book_file_validator_spec.rb"
Task: "Write spec/validators/cover_image_validator_spec.rb"
Task: "Write spec/models/category_spec.rb"
Task: "Write spec/models/categorization_spec.rb"
Task: "Write spec/models/book_spec.rb"

# Independent implementation files together (after migrations T031–T033):
Task: "Implement app/validators/book_file_validator.rb"
Task: "Implement app/validators/cover_image_validator.rb"
Task: "Implement app/models/category.rb"
Task: "Implement app/models/categorization.rb"
```

## Parallel Example: User Story 4

```bash
Task: "Write spec/models/reading_position_spec.rb"
Task: "Write spec/models/bookmark_spec.rb"
# after T058–T059:
Task: "Implement app/models/reading_position.rb"
Task: "Implement app/models/bookmark.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup, then Phase 2 Foundational.
2. Phase 3 (US1): hardened sign-in with lockout, normalized email, name and role.
3. **Stop and validate**: the US1 specs, plus Playwright on mobile then desktop.
   Sign-in is the app's first page, so this is shippable on its own.

### Incremental Delivery

1. US2 (catalog), then US3 (library) and US4 (resume). That completes the P1 data
   foundation for reading.
2. US7 (search) next, since the search page is the first screen feature planned.
3. US5 (notes) and US6 (reviews).
4. US8 (conversions) and US9 (share).
5. Polish: seeds, benchmark, FR coverage map, quality gates, live check.

## Notes

- `[P]` means different files with no dependency on incomplete tasks.
- Commit after each task or checkpoint.
- Do not cache authentication lookups (session, sign-in user, lockout state), per the
  plan's Complexity Tracking.
- Never write file bytes into `Rails.cache`.

## Implementation notes (2026-10-14)

Where the build differed from the task text, and why:

- **Home route (user request)**: the root is not the sign-in page. `GET /` and `GET /home`
  (`home_url`) render a blank, sign-in-only `HomeController#show`, the future search page.
  Sign-in lands on `home_url` (T014, contracts/sign-in.md).
- **Cache-hit query counts**:
  - per-user and per-book reads hit with **0** queries (reading position, bookmarks,
    notes, reviews)
  - reads keyed on `Book.catalog_version` (catalog search, library search) or on a
    relation version (category dropdown) hit with **1** query, the cheap version lookup
    that keeps them correct
- **Library ordering**: "most recently read first" needs `reading_positions`. It was added
  in US4 (T062), and `library.search` also returns `reading_location`, `reading_progress`
  and `last_read_at` per entry (FR-034).
- **Relevance**: ranks by `word_similarity`, then `similarity`, then title. With
  `word_similarity` alone, an exact title tied with any title containing the word.
- **Reading direction on kind change**: an explicit direction is recognized only when it
  differs from the stored value (Rails dirty tracking).
- **System spec block**: the empty `before(:each, type: :system)` block in
  `spec/rails_helper.rb` holds the user's driver notes and was left in place. Viewport
  driving lives in `spec/support/system_viewports.rb`.
- **Rubocop**: 2 pre-existing whitespace offenses remain in files this feature did not
  touch (`Gemfile` final newline, a comment indent in `spec/rails_helper.rb`).
- **Extra coverage**: added FR-022 (book delete cascade) and FR-042 (notes never change the
  book) examples while building fr-coverage.md.
