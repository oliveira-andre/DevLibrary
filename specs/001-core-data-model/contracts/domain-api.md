# Contract: Domain API for Future Features

**Covers**: FR-005, FR-006, FR-012–FR-051 · **Data**: [data-model.md](../data-model.md)

Later screen features (search, book page, reader, library, reviews, notes, downloads,
sharing) build on these model-level entry points. Signatures, return values and errors are
stable. Internals may change. All reads listed as *cached* go through `Rails.cache` with
the keys in data-model.md.

Errors: `ActiveRecord::RecordInvalid` for rule violations (with messages), and
`ActiveRecord::RecordNotFound` for missing or invisible records.

## Accounts

| Call | Returns | Notes |
|---|---|---|
| `User.new(attrs).save(context: [:create, :sign_up])` | `true/false` | the sign-up feature uses this. `name` required. `role` must never be permitted from params |
| `User.authenticate_with_lockout(email_address:, password:)` | `User` or `nil` | `nil` for unknown, wrong or locked. Updates counters (see [sign-in.md](sign-in.md)) |
| `user.locked?` | Boolean | |
| `user.admin?` / `user.reader?` | Boolean | the authorization predicate for admin-only actions |

## Catalog

| Call | Returns | Notes |
|---|---|---|
| `Book.visible_to(user)` | relation | admin: all. Reader: published, plus archived books in their library |
| `Book.find_visible!(public_id, user:)` | `Book` | raises `RecordNotFound` for drafts and deleted books (FR-055). Share links resolve through this |
| `Book.search(query: nil, category: nil, sort: nil, page: 1, per: 24)` | `Array<Book>` (covers preloaded), *cached* | published only. `sort` ∈ `relevance` (default with query), `newest` (default without), `title_asc`, `title_desc`, `top_rated`. `relevance` without a query falls back to `newest` |
| `Category.cached_ordered` | `Array<Category>`, *cached* | for the search category dropdown |
| `book.publish!` / `archive!` / `unpublish!` | `true` | raises `RecordInvalid` if publishing without a file (FR-018) |
| `book.to_param` | `public_id` | share link and route parameter |
| `book.convertible_to?(:pdf/:epub)` | Boolean | false when it matches `file_format` |

## Personal library

| Call | Returns | Notes |
|---|---|---|
| `user.library` | `Library` | always present (FR-012) |
| `library.add!(book)` | `LibraryEntry` | idempotent. Raises if the book is not published |
| `library.remove!(book)` | `true` | removes the entry and all its placements. Keeps positions, notes and bookmarks (FR-028) |
| `library.favorite!(book)` / `unfavorite!(book)` | `true` | favorite adds to the library if needed (FR-032) |
| `library.favorited?(book)` | Boolean | heart state |
| `library.place!(book, shelf:)` / `unplace!(book, shelf:)` | `true` | place adds to the library if needed (FR-031) |
| `library.shelves.create!(name:)` | `Shelf` | unique per library ignoring case. "Favorites" reserved |
| `library.search(query: nil, shelf: nil)` | `Array<LibraryEntry>` with book, cover and position, *cached* | FR-033/FR-034. Ordered by last read, then date added |

## Reading

| Call | Returns | Notes |
|---|---|---|
| `ReadingPosition.record!(user:, book:, location:, progress:, read_at:)` | `ReadingPosition` | newest `read_at` wins. Future times clamped (FR-038) |
| `ReadingPosition.for(user:, book:)` | `ReadingPosition` or `nil`, *cached* | resume point |
| `position.effective_reading_direction` | `"ltr"` / `"rtl"` | override, else the book's direction |
| `ReadingPosition.set_direction!(user:, book:, direction:)` | `ReadingPosition` | `nil` direction clears the override (FR-039) |
| `user.bookmarks.create!(book:, location:, progress:, label:)` | `Bookmark` | unique per position |
| `user.notes.create!(book:, location:, progress:, content:)` | `Note` | |
| `Note.for(user:, book:)` / `Bookmark.for(user:, book:)` | `Array`, *cached*, in book order | FR-043 |

## Reviews

| Call | Returns | Notes |
|---|---|---|
| `book.reviews.create!(user:, rating:, content:)` | `Review` | one per user per book. Published books only |
| `review.update!(...)` / `review.destroy!` | | the book's average and count stay accurate |
| `Review.for_book(book, page:)` | `Array<Review>` with author name, *cached* | |

## Conversions

| Call | Returns | Notes |
|---|---|---|
| `Conversion.request!(book:, target_format:, user:)` | `Conversion` | idempotent per file version. Retries a `failed` one. Raises for the same format as the original |
| `conversion.start!` / `complete!(io:, filename:)` / `fail!(reason)` / `retry!` | `true` | state machine in data-model.md. Used by the future conversion job |
