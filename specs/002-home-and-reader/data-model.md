# Data Model: Home Page, Book Page and Reader

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Research**: [research.md](research.md)
· **Builds on**: [001 data model](../001-core-data-model/data-model.md)

This feature adds **two migrations** (reading settings on `users`, and `users.blocked_at`)
and no new tables. Everything else reuses the 001 records through new read paths, each
cached per Principle IX.

## users (extended): reading settings

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| reader_page_animation | boolean | no | `true` | FR-031, FR-032. `false` = instant page changes |
| reader_theme | string | no | `"light"` | CHECK in (light, sepia, dark). FR-027, FR-033 |
| reader_text_size | integer | no | `100` | percent. CHECK in (80, 90, 100, 115, 130, 150, 175). FR-027 |

**Why columns on `users`, not a settings table** (research R7): the reader already has
`Current.user` loaded on every request, so the settings cost no query and no cache entry.
Changes are rare, and each change bumps the user's `updated_at`. That is the version every
per-user cache key already embeds.

**Concern**: `User::ReadingSettings` (`app/models/user/reading_settings.rb`), next to
`User::Lockable`:

- `TEXT_SIZES = [80, 90, 100, 115, 130, 150, 175]`. The default is the third step (100).
- `enum :reader_theme, { light:, sepia:, dark: }, prefix: true, validate: true`. Gives
  `reader_theme_dark?` and does not clash with any other enum.
- `validates :reader_text_size, inclusion: { in: TEXT_SIZES }`.
- `validates :reader_page_animation, inclusion: { in: [true, false] }`.
- `reading_settings` → `{ page_animation:, theme:, text_size: }`, the hash the reader and the
  settings form render from.
- `update_reading_settings(attrs)` permits only the three keys and returns `true/false`.

**Migration**: `AddReadingSettingsToUsers`. Adds the three columns with defaults and
`null: false`, plus two check constraints: `users_reader_theme_check` and
`users_reader_text_size_check`. Existing rows get the defaults.

## users (extended): blocked state

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| blocked_at | datetime | yes | | set when the maintainers block the account. `nil` = not blocked (FR-051) |

**Concern**: `User::Blockable` (`app/models/user/blockable.rb`), research R18.
- `blocked?` → `blocked_at.present?`.
- `block!` sets `blocked_at = Time.current` and runs `sessions.destroy_all` in one
  transaction (FR-052). It is idempotent.
- `unblock!` sets `blocked_at = nil`.
- Blocking never changes `role`, `failed_sign_in_attempts`, `locked_until` or
  `lockout_count`. The 001 password-change callback (`clear_sign_in_lockout!`) never
  touches `blocked_at` (FR-051).

**Lockable changes** (`app/models/user/lockable.rb`):
- `authenticate_with_lockout` returns `nil` for a blocked user after a timing-parity
  `authenticate`, without counting the failure.
- `register_failed_sign_in!` returns early for blocked users (FR-054). When it starts a new
  lock, it enqueues `PasswordsMailer.locked(user)` after commit, once per lockout (FR-053).

**Migration**: `AddBlockedAtToUsers` adds the nullable column and a partial index
`WHERE blocked_at IS NOT NULL`, so maintainers can list blocked accounts.

## books (unchanged columns): cover variants

`has_one_attached :cover` gains named variants. They are preprocessed on attach, so the
first viewer never waits for the resize:

| Variant | Transformation | Used by |
|---|---|---|
| `:card` | `resize_to_fill: [480, 720]`, WebP | home cards, collection row, search results (rendered at up to 240×360 CSS px, 2× density; enlarged 2026-10-25) |
| `:large` | `resize_to_limit: [600, 900]`, WebP | book page |
| `:preview` | `resize_to_limit: [1200, 1200]`, JPEG | public link-preview image (research R17). JPEG because some preview apps reject WebP |

A missing cover renders the placeholder partial. No variant is requested (spec edge case).

## Read paths and query objects

### `Book::Recent` (new, `app/models/book/recent.rb`)

The newest list on the home page (FR-003, FR-004). It uses **keyset pagination**, so
publishing or deleting a book between loads cannot repeat or skip anything (research R3).

- Scope: `Book.published.order(published_at: :desc, id: :desc)`, covers preloaded.
- Cursor: an opaque string encoding `(published_at, id)` of the last book shown. The next
  batch is `WHERE (published_at, id) < (cursor_published_at, cursor_id)`. The existing
  `(status, published_at)` index serves it.
- Fetches `per + 1` rows. The extra row only decides whether a next cursor exists.
- Returns `Book::Page`.
- An invalid or tampered cursor is treated as "first page", never as an error.

### `Book::Page` (new value object, `app/models/book/page.rb`)

`Data.define(:books, :next_params)`. `next_params` is `nil` on the last page. Otherwise it
is the query hash for the "See more" link (`{ before: cursor }` for recent, `{ page: n }`
for search).

### `Book.search_page` (new, beside the existing `Book.search`)

Search results with "See more" (FR-011). It wraps `Book::Search` with `per + 1` look-ahead
and returns `Book::Page` with `next_params: { page: n + 1 }`. `Book.search` and its 001
contract are unchanged. Offset paging stays for search, because relevance order cannot be
keyset-paged cheaply. Repeats are prevented in the browser instead: each card's DOM id is
`dom_id(book)`, and Turbo's `append` replaces an element whose id already exists (FR-011,
research R3).

### `Book.find_visible_cached!(public_id, user:)` (new)

The book page and the reader look up the book through this. It wraps 001's
`find_visible!` and preloads the cover, file blob, categories and rich-text description.
It raises `RecordNotFound` for drafts and deleted books (FR-019).

### `Book.published_preview(public_id)` (new)

The only signed-out read of a book (FR-047, research R17). It returns
`Book::Preview = Data.define(:public_id, :title, :authors, :cover_blob_id)` for a
**published** book, or `nil` for anything else (draft, archived, deleted, unknown). It
selects only those columns plus the cover attachment's blob id. The description, reviews,
rating and categories are never loaded, so a template cannot leak them.

### `Library#state_for(book)` (new)

Returns `{ in_library: Boolean, favorited: Boolean }` for the book page's collection
button and heart (FR-020). One query, cached per user.

### `Review.by(user, book:)` (new)

Returns the person's own review of the book, or `nil`. The book page uses it to choose
between the form and "your review" (FR-017).

### Reused from 001, unchanged

| Call | Used by |
|---|---|
| `library.search` | the "Your collection" row: ordered by last read, then date added, carrying `reading_progress` (FR-006–FR-008) |
| `Book.search` / `Book::Search` | search results (through `search_page`) |
| `Category.cached_ordered` | the category dropdown |
| `Review.for_book(book, page:)` | review list, 20 per page (FR-014) |
| `ReadingPosition.for(user:, book:)` | reader start position (FR-022) and the "Continue reading (42%)" label |
| `ReadingPosition.record!` | every page turn (FR-023) |
| `ReadingPosition.set_direction!` | the direction switch (FR-026) |
| `library.add!` / `remove!` / `favorite!` / `unfavorite!` | collection button and heart (FR-020) |
| `book.reviews.create` / `review.update` / `review.destroy` | review form, edit modal, delete (FR-015–FR-018) |

## Cache keys and invalidation (Principle IX)

New entries only. The 001 table still applies to everything reused.

| Read | `Rails.cache` key | Invalidated by |
|---|---|---|
| Home newest batch | `["catalog/recent", Book.catalog_version, cursor, per]` | any book create, update or delete; categorization, review and conversion changes (all touch the book) |
| Search results batch | `["catalog/search_page", Book.catalog_version, normalized_q, category_id, sort, page, per]` | same as above |
| Visible book with preloads | `["book/visible", Book.catalog_version, public_id, user.cache_key_with_version]` | any catalog change; the user's library changes (entry → library → user touch chain), because archived visibility depends on it |
| Collection/favorite state for a book | `[user.cache_key_with_version, "library_state", book.id]` | library entry and shelf placement writes (touch chain to the user) |
| Own review of a book | `["book", book.cache_key_with_version, "review_by", user.id]` | any review create, update or delete on that book (`refresh_rating!` bumps the book's `updated_at`) |
| Signed-out book preview | `["book/preview", Book.catalog_version, public_id]` | any catalog change, including publish, unpublish, archive and delete. An unpublished book returns `nil` on the next read |

**Not cached, on purpose**:
- Reading settings and `blocked_at`: read from `Current.user`, which authentication
  already loads. Caching them would add a lookup rather than remove one. A cached blocked
  flag could also keep a blocked session alive (001 security exception).
- File bytes: streamed by `books/files#show` straight from Active Storage, never through
  `Rails.cache` (research R6). The blob row comes from the cached visible-book read.
- Cover URLs: signed with an expiry rounded to the hour window, so each URL stays the same
  for an hour and the browser cache can reuse it (research R13). Only the URL is computed;
  nothing is stored.

## State and validation rules touched by this feature

- **Reading settings**: invalid theme or text size → `RecordInvalid` / 422. Only the owner
  can change them, because the endpoint is singular and always acts on `Current.user`
  (FR-038).
- **Reviews**: the 001 rules apply as they are. The HTTP layer adds authorization: only the
  author may update, and the author or an admin may destroy (FR-018). See
  [contracts/http.md](contracts/http.md).
- **Reading position**: the 001 newest-wins rule is what makes the browser's retry outbox
  safe. Re-sending an old event can never overwrite a newer one (FR-023, research R5).
