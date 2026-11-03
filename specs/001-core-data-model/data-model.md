# Data Model: Core Data Model

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Research**: [research.md](research.md)

PostgreSQL, UTF-8 (`encoding: unicode`). Every enum is a string column backed by a Rails
`enum ... validate: true` plus a database `CHECK` constraint (research R5). Foreign keys use
database constraints **without** `ON DELETE CASCADE`. Deletion goes through
`dependent: :destroy`, so callbacks, touches and file purges always run (R13).

## Entity overview

```text
User 1──1 Library 1──* LibraryEntry *──1 Book *──* Category   (via Categorization)
 │            └──* Shelf 1──* ShelfPlacement *──1 LibraryEntry
 ├──* Session
 ├──* ReadingPosition *──1 Book
 ├──* Bookmark        *──1 Book
 ├──* Note            *──1 Book
 ├──* Review          *──1 Book
 └──* Conversion (as requested_by, nullified on user delete) *──1 Book
```

Extensions: `pg_trgm`. New framework tables: `action_text_rich_texts` (from
`action_text:install`). The `active_storage_*` tables already exist.

---

## users (existing, extended)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| email_address | string | no | | exists; unique index exists |
| password_digest | string | no | | exists |
| name | string | no | `""` | FR-005 |
| role | string | no | `"reader"` | CHECK in (reader, admin). FR-006 |
| failed_sign_in_attempts | integer | no | `0` | consecutive failures since the last lock or success |
| locked_until | datetime | yes | | account locked while `> now` |
| lockout_count | integer | no | `0` | consecutive lockouts without a success. Drives doubling |

**Associations**: `has_many :sessions` (existing) · `has_one :library, dependent: :destroy` ·
`has_many :reading_positions, :bookmarks, :notes, :reviews, dependent: :destroy` ·
`has_many :requested_conversions, class_name: "Conversion", foreign_key: :requested_by_id,
dependent: :nullify`

**Normalization**: `email_address` → `strip.downcase` (existing `normalizes`; also applies to
`find_by`/`authenticate_by` lookups, FR-001/FR-002) · `name` → `strip`.

**Validations**
- `email_address`: presence; format `URI::MailTo::EMAIL_REGEXP`; uniqueness (normalized
  value + existing unique index).
- `password`: length 8..72, `allow_nil: true`. `has_secure_password` already enforces
  presence on create, confirmation, and the 72-byte cap.
- `name`: length ≤ 100. Presence **only in the `:sign_up` context** (call
  `save(context: [:create, :sign_up])`). On update it cannot be cleared: error if
  `name_was.present? && name.blank?`.
- `role`: enum inclusion. Self sign-up never permits `role` (enforced by the sign-up
  feature's strong params; documented in [contracts/domain-api.md](contracts/domain-api.md)).

**Callbacks**
- `after_create` → `create_library!`, which creates its Favorites shelf (FR-012). Runs in
  the same transaction.
- `after_update` when `saved_change_to_password_digest?` → `clear_sign_in_lockout!` (FR-010,
  password reset).
- `after_save` when `saved_change_to_name?` → touch the books this user reviewed, because
  reviews display the author's name (cache cascade, R10).

**Sign-in protection** (R6): `locked?` · `register_failed_sign_in!` · `register_successful_sign_in!`
· `clear_sign_in_lockout!` · `User.authenticate_with_lockout(email_address:, password:)`.
Counters are written under a row lock (`with_lock`) with `update_columns`.

```text
failure while unlocked:
  attempts = failed_sign_in_attempts + 1
  attempts >= 5 → locked_until = now + min(15.min × 2^lockout_count, 24.h)
                  lockout_count += 1, failed_sign_in_attempts = 0
  else          → failed_sign_in_attempts = attempts
attempt while locked:  refused; counters unchanged (lock not extended)
success / password change: failed_sign_in_attempts = 0, lockout_count = 0, locked_until = nil
```

---

## categories

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| name | string | no | | ≤ 50, `squish` normalized |
| timestamps | | | | |

**Indexes**: unique on `lower(name)`.
**Associations**: `has_many :categorizations, dependent: :destroy` · `has_many :books, through: :categorizations`
**Validations**: name presence, length ≤ 50, `uniqueness: { case_sensitive: false }` (FR-019).
**Callbacks**: `after_save` when the name changed → `books.touch_all` (cache cascade).

## categorizations (book ↔ category)

| Column | Type | Null | Notes |
|---|---|---|---|
| book_id | references | no | FK |
| category_id | references | no | FK |
| timestamps | | | |

**Indexes**: unique `(book_id, category_id)`; `category_id`.
**Associations**: `belongs_to :book, touch: true` · `belongs_to :category, touch: true`

---

## books

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| title | string | no | | ≤ 255 (FR-013) |
| authors | string[] | no | `[]` | free-text names |
| kind | string | no | `"book"` | CHECK in (book, comic, manga, storybook) (FR-015) |
| reading_direction | string | no | `"ltr"` | CHECK in (ltr, rtl) (FR-016) |
| status | string | no | `"draft"` | CHECK in (draft, published, archived) (FR-017) |
| published_at | datetime | yes | | set on first publish; "Newest" sort key |
| public_id | string | no | | 12-char base58, unique, never changes (FR-021, R7) |
| file_format | string | yes | | CHECK in (pdf, epub, cbz, cbr); set from sniffed bytes |
| search_text | text | no | `""` | normalized title + authors (R4) |
| average_rating | decimal(3,2) | no | `0` | maintained by reviews (FR-047) |
| reviews_count | integer | no | `0` | maintained by reviews |
| timestamps | | | | |

**Indexes**: unique `public_id`; GIN `search_text gin_trgm_ops`; `(status, published_at)`;
`(status, average_rating, reviews_count)`; `(status, title)`.

**Rich text / attachments**: `has_rich_text :description` · `has_one_attached :cover` ·
`has_one_attached :file`

**Enums**: `kind` with `prefix: true` (`kind_manga?`, `Book.kind_manga`), plus
`reading_direction` and `status`.

**Associations**: `has_many :categorizations` · `has_many :categories, through:` ·
`has_many :library_entries` · `has_many :reading_positions` · `has_many :bookmarks` ·
`has_many :notes` · `has_many :reviews` · `has_many :conversions`. All
`dependent: :destroy` (FR-022).

**Validations**
- `title`: presence, length ≤ 255.
- `file`: `BookFileValidator` (R2). Format is detected from the bytes (pdf, epub, cbz, cbr)
  and the size must be ≤ 500 MB. It must be attached when `published?` (FR-018).
- `cover`: `CoverImageValidator`. Bytes must be JPEG, PNG or WebP, ≤ 10 MB.

**Callbacks**
- `before_validation`: on create, or when `kind` changed and `reading_direction` did not,
  set the direction to `rtl` for manga and `ltr` otherwise (FR-016).
- `before_validation` on create: generate `public_id` (retry on collision).
- `before_save`: recompute `search_text`; set `file_format` from the validator's detection;
  set `published_at` on the first transition to `published`.
- `after_save` when the file attachment changed → destroy conversions whose
  `source_checksum` ≠ the new blob checksum (FR-051).

**Scopes / class methods**: `published` · `visible_to(user)` (admin → all; reader →
published, plus archived books in that user's library) · `Book.search(...)` (see
[contracts/domain-api.md](contracts/domain-api.md)) · `Book.catalog_version`
(`"#{count}-#{maximum(:updated_at)}"`).

**Instance methods**: `to_param` → `public_id` · `refresh_rating!` · `convertible_to?(format)`
· `current_file_checksum`.

**Status transitions** (admin only):

```text
draft ──publish (needs title + file)──▶ published ──archive──▶ archived
  ▲                                         │  ▲                 │
  └──────────────── unpublish ──────────────┘  └──── republish ──┘
any status ──delete──▶ (gone, cascade per FR-022)
```

---

## libraries

| Column | Type | Null | Notes |
|---|---|---|---|
| user_id | references | no | unique, FK |
| timestamps | | | |

**Associations**: `belongs_to :user, touch: true` · `has_many :entries, class_name: "LibraryEntry",
dependent: :destroy` · `has_many :books, through: :entries` · `has_many :shelves,
dependent: :destroy` · `has_one :favorites_shelf, -> { kind_favorites }, class_name: "Shelf"`

**Callbacks**: `after_create` → create the Favorites shelf.

**Domain methods**: `add!`, `remove!`, `favorite!`, `unfavorite!`, `favorited?`, `place!`,
`unplace!`, `search`. See [contracts/domain-api.md](contracts/domain-api.md).

## library_entries

| Column | Type | Null | Notes |
|---|---|---|---|
| library_id | references | no | FK |
| book_id | references | no | FK |
| timestamps | | | `created_at` = date added |

**Indexes**: unique `(library_id, book_id)`; `book_id`.
**Associations**: `belongs_to :library, touch: true` · `belongs_to :book` ·
`has_many :shelf_placements, dependent: :destroy` · `has_many :shelves, through:`
**Validations**: uniqueness of book within the library; the book must be `published` on create
(FR-027).

## shelves

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| library_id | references | no | | FK |
| name | string | no | | ≤ 50, `squish` |
| kind | string | no | `"custom"` | CHECK in (favorites, custom) |
| timestamps | | | | |

**Indexes**: unique `(library_id, lower(name))`; partial unique `(library_id) WHERE kind = 'favorites'`.
**Associations**: `belongs_to :library, touch: true` · `has_many :shelf_placements, dependent: :destroy`
· `has_many :entries, through: :shelf_placements, source: :library_entry`
**Validations**: name presence, length ≤ 50, uniqueness per library case-insensitive (FR-029);
a custom shelf cannot be named "favorites" in any casing.
**Guards**: the Favorites shelf cannot be renamed (`before_update` error) or destroyed
(`before_destroy` aborts unless `destroyed_by_association`) (FR-030).

## shelf_placements

| Column | Type | Null | Notes |
|---|---|---|---|
| shelf_id | references | no | FK |
| library_entry_id | references | no | FK |
| timestamps | | | |

**Indexes**: unique `(shelf_id, library_entry_id)`; `library_entry_id`.
**Associations**: `belongs_to :shelf, touch: true` · `belongs_to :library_entry, touch: true`
**Validations**: shelf and entry must belong to the same library.

---

## reading_positions

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| user_id | references | no | | FK |
| book_id | references | no | | FK |
| location | string | yes | | opaque locator: page number (PDF/CBZ/CBR) or EPUB CFI. `nil` = not started |
| progress | decimal(5,2) | no | `0` | 0–100 |
| read_at | datetime | yes | | device time of the reading event. Newest wins |
| reading_direction | string | yes | | per-user override, CHECK in (ltr, rtl) (FR-039) |
| timestamps | | | | |

**Indexes**: unique `(user_id, book_id)`; `book_id`.
**Associations**: `belongs_to :user, touch: true` · `belongs_to :book`. No touch on book,
because page turns must not invalidate the catalog.
**Validations**: progress 0..100; `reading_direction` inclusion or nil.
**Rules**: `ReadingPosition.record!` creates or updates under a row lock and ignores
updates whose `read_at` is older than the stored one (FR-038). A `read_at` more than one
minute in the future is clamped to now (R8). The record persists without a library entry
(FR-037) and survives library removal (FR-028).
**Method**: `effective_reading_direction` → override, else `book.reading_direction`.

## bookmarks

| Column | Type | Null | Notes |
|---|---|---|---|
| user_id | references | no | FK |
| book_id | references | no | FK |
| location | string | no | opaque locator |
| progress | decimal(5,2) | no, `0` | sort key ("book order") |
| label | string | yes | ≤ 100 |
| timestamps | | | |

**Indexes**: unique `(user_id, book_id, location)`; `(user_id, book_id, progress)`.
**Associations**: `belongs_to :user, touch: true` · `belongs_to :book`
**Validations**: location presence; uniqueness scoped to user + book (FR-040); label ≤ 100;
progress 0..100.

## notes

| Column | Type | Null | Notes |
|---|---|---|---|
| user_id | references | no | FK |
| book_id | references | no | FK |
| location | string | no | where it was written |
| progress | decimal(5,2) | no, `0` | sort key |
| timestamps | | | |

**Rich text**: `has_rich_text :content`. Action Text's `RichText` touches the note, and the
note touches the user.
**Indexes**: `(user_id, book_id, progress)`.
**Associations**: `belongs_to :user, touch: true` · `belongs_to :book`
**Validations**: `content.to_plain_text.strip` present and ≤ 10,000 characters (FR-041);
location presence; progress 0..100.
**Scope**: `in_book_order` → `order(:progress, :created_at)` (FR-043).

## reviews

| Column | Type | Null | Notes |
|---|---|---|---|
| user_id | references | no | FK |
| book_id | references | no | FK |
| rating | integer | no | CHECK 1..5 |
| timestamps | | | |

**Rich text**: `has_rich_text :content`
**Indexes**: unique `(user_id, book_id)`; `(book_id, created_at)`.
**Associations**: `belongs_to :user` · `belongs_to :book`
**Validations**: `rating` numericality `only_integer: true, in: 1..5`. This runs on the raw
input, so `"3.5"` is rejected rather than truncated to 3. Content plain text present and
≤ 5,000 characters. Uniqueness of user per book (FR-045). The book must be `published` on
create (FR-044).
**Callbacks**: `after_save` and `after_destroy` (inside the transaction) →
`book.refresh_rating!`, skipped when `destroyed_by_association` is the book (FR-047).
`refresh_rating!` writes `average_rating`, `reviews_count` and `updated_at` in one
`update_columns`.

## conversions

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| book_id | references | no | | FK |
| requested_by_id | references → users | yes | | first requester. Nullified on user delete |
| source_checksum | string | no | | checksum of the book file blob it was made from |
| target_format | string | no | | CHECK in (pdf, epub) |
| status | string | no | `"pending"` | CHECK in (pending, processing, completed, failed) |
| failure_reason | text | yes | | kept until a later success |
| attempts | integer | no | `0` | |
| timestamps | | | | |

**Attachment**: `has_one_attached :output`
**Indexes**: unique `(book_id, source_checksum, target_format)`; `status`.
**Associations**: `belongs_to :book, touch: true` · `belongs_to :requested_by, class_name: "User", optional: true`
**Validations**: `target_format` ≠ `book.file_format` (FR-049); book file attached; `output`
attached when `completed`.

**State machine** (FR-050):

```text
pending ──start!──▶ processing ──complete!(file)──▶ completed   (failure_reason cleared)
   ▲                    │
   │                    └──fail!(reason)──▶ failed ──retry!──▶ pending (attempts += 1)
```

`Conversion.request!(book:, target_format:, user:)` returns the existing row for the current
checksum (`create_or_find_by`). A `failed` row is retried. A `completed` row is reused
(FR-049). The conversion engine itself is out of scope, so this feature only stores the
state.

---

## Cache keys and invalidation (Principle IX, research R10)

| Read | `Rails.cache` key | Invalidated by |
|---|---|---|
| Catalog search page | `["catalog/search", Book.catalog_version, normalized_q, category_id, sort, page]` | any book create/update/delete; categorization changes (touch book); category rename (touch books); review changes (`refresh_rating!` bumps book `updated_at`); conversion changes (touch book) |
| Category dropdown | `["categories", Category.order(:name).cache_key_with_version]` | category create/update/delete; categorization touch |
| Book detail incl. reviews and formats | `["book", book.cache_key_with_version, ...]` | book update; description (RichText touch); reviews; conversions; categorizations; reviewer rename |
| Personal library listing / search | `[user.cache_key_with_version, "library", Book.catalog_version, q, shelf_id]` | entries, shelves and placements (touch chain → library → user); reading positions (touch user); any catalog change |
| Reading position for a book | `[user.cache_key_with_version, "reading_position", book.id]` | any of that user's reading, bookmark, note or library writes (touch user) |
| Bookmarks / notes for a book | `[user.cache_key_with_version, "bookmarks"/"notes", book.id]` | same as above |

`Current.user` is loaded on every authenticated request, so per-user cache versions cost no
extra query. Binary content (files, covers, outputs) is never written to `Rails.cache`.
