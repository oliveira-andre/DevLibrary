# Research: Core Data Model

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md)

All Technical Context unknowns are resolved below. No new gems are required.

## R1. Rich text with emoji (descriptions, reviews, notes)

- **Decision**: Use Action Text (`has_rich_text`) for `Book#description`, `Review#content` and
  `Note#content`. Install it with `bin/rails action_text:install`, which adds the
  `action_text_rich_texts` table. Emoji are stored natively, because the database is UTF-8.
  Length and presence rules validate `to_plain_text`, so markup does not count toward limits.
- **Editor**: The installer ships Trix. Basecamp's Lexxy is a newer Action Text editor
  built on Lexical, and it is positioned as Trix's successor. The storage format is Action
  Text either way, so the editor and emoji picker are chosen by the first screen feature
  that edits rich text. This feature only needs the storage.
- **Alternatives considered**: Markdown in a text column (no inline attachments, needs
  custom sanitizing); a JSON document column (custom renderer, no Rails integration).

## R2. Validating book and cover files by content

- **Decision**: Use custom validators, `BookFileValidator` and `CoverImageValidator` in
  `app/validators/`. They read the first bytes of the upload and identify the type with
  Marcel by magic bytes only, ignoring the file name and the declared type:
  - `application/pdf` → `pdf`
  - ZIP whose bytes 30–57 read `mimetypeapplication/epub+zip` → `epub`
  - other ZIP with a `.cbz` filename → `cbz`; RAR signature with a `.cbr` filename → `cbr`
  - covers: JPEG, PNG or WebP magic only
  - size caps: 500 MB for books, 10 MB for covers

  The detected format is stored in `books.file_format`.
- **Rationale**: `blob.content_type` cannot be trusted. Active Storage's direct-upload path
  does not run server-side identification. A related flaw, CVE-2026-33173 (fixed in Rails
  8.1.2.1; the app runs 8.1.4), let clients skip identification entirely. Sniffing the
  bytes ourselves closes both gaps.
- **Alternatives considered**: The `active_storage_validations` gem (2.x). It works, but
  its checks rely on identified content types, and it adds a dependency for about 40 lines
  of code. Trusting the extension contradicts FR-014.

## R3. No permanent public file links (FR-052, Principle VIII)

- **Decision**:
  - Set `config.active_storage.urls_expire_in = 1.hour`, so redirect and proxy URLs
    expire. They never expire by default.
  - Include the `Authentication` concern in `ActiveStorage::BaseController` from a
    `to_prepare` initializer, so every Active Storage route requires a signed-in session.
  - Book files and conversion outputs are delivered to readers only through app
    controllers with authorization (download feature). This feature adds the global guard
    and a request spec proving an anonymous blob request redirects to sign-in.
- **Gotcha**: Active Storage controllers live in an engine namespace. The concern's
  redirect must use `main_app.new_session_path`.
- **Alternatives considered**: `draw_routes = false` and re-drawing every route by hand (more
  surface to maintain); leaving the defaults (Rails docs warn that anyone with the URL can
  fetch the file).

## R4. Accent-insensitive partial-word catalog search (FR-023–FR-026, SC-007)

- **Decision**:
  - Enable `pg_trgm`.
  - Store `books.search_text`: title plus authors, NFD-decomposed. Combining marks are
    removed only after Latin letters, then the text is recomposed and lowercased. "Café"
    becomes "cafe", while Japanese kana keep their dakuten (バ stays バ).
  - Add a GIN `gin_trgm_ops` index. The query is normalized the same way and split into
    terms, and every term must match (`search_text LIKE %term%`, escaped).
  - Relevance = `word_similarity(query, search_text)` descending, then title.
- **Rationale**: Trigram indexes serve `LIKE '%…%'` and handle partial words and CJK titles.
  Normalizing in Ruby avoids `unaccent()`, which is not IMMUTABLE and so cannot be indexed
  without a wrapper function.
- **Alternatives considered**: The `pg_search` gem (extra dependency, tsearch weak on partial
  words and CJK); the `unaccent` extension with an immutable wrapper (more database
  surface); `I18n.transliterate` (turns non-Latin scripts into `?`, which breaks manga
  titles).

## R5. Enumerated values

- **Decision**: String columns, Rails `enum :x, {...}, validate: true` (invalid values become
  validation errors, not `ArgumentError`), plus a `CHECK` constraint in the migration.
  `Book#kind` uses `prefix: true` to avoid `Book.book`.
- **Alternatives considered**: Integer enums (unreadable in SQL, order-fragile); native
  Postgres enum types (awkward to extend, since values cannot be removed).

## R6. Account lockout against proxy-distributed guessing (FR-007–FR-011)

- **Decision**:
  - Columns on `users`: `failed_sign_in_attempts`, `locked_until`, `lockout_count`.
  - `User.authenticate_with_lockout` wraps `authenticate_by`, which already normalizes the
    email and takes the same time for unknown emails.
  - When the account is locked, the password is still checked (and the result discarded),
    so response timing does not reveal the lock.
  - Counters update under `with_lock`, so parallel requests from many IPs cannot race past
    the threshold.
  - 5 consecutive failures lock the account for 15 min × 2^lockouts, capped at 24 h.
  - A success or a password change resets everything (a model callback on
    `password_digest`, so the existing reset flow needs no controller logic).
  - The existing per-IP `rate_limit` (10 per 3 minutes) stays.
  - Every failure redirects with the existing generic alert "Try another email address or
    password."
- **Alternatives considered**: Rack::Attack (extra gem, keyed on request data rather than
  account state); a separate attempts table (more writes, no benefit at this scale); a
  permanent lock until reset (an attacker could permanently block victims).

## R7. Stable public identifier for share links (FR-021, FR-053)

- **Decision**: `books.public_id` = `SecureRandom.base58(12)`, generated on create, unique
  index, never updated. `Book#to_param` returns it, so routes read `/books/:public_id`.
- **Alternatives considered**: A title slug (changes with the title); `has_secure_token`
  (minimum 24 characters, which makes links long); exposing numeric ids (enumerable).

## R8. Reading position: format-agnostic, newest wins (FR-036–FR-039)

- **Decision**:
  - `location` is an opaque string: a page number for PDF, CBZ and CBR, or an EPUB CFI.
  - `progress` (0–100) is the format-independent sort key, also used by notes and
    bookmarks for "book order".
  - `read_at` is the device timestamp. `record!` uses `create_or_find_by` on the unique
    `(user_id, book_id)` index, then `with_lock`, and updates only when the incoming
    `read_at` is newer than the stored one.
  - A `read_at` more than one minute in the future is clamped to now, so a device with a
    wrong clock cannot freeze the position.
  - The per-user direction override lives on the same row, with a nil location until
    reading starts.
- **Alternatives considered**: Separate page and CFI columns (couples the data to reader
  internals); `upsert` with a conditional `ON CONFLICT ... WHERE` (skips callbacks, so the
  user touch would never fire and per-user caches would go stale).

## R9. Average rating and review count (FR-047, top-rated sort)

- **Decision**: Denormalize `average_rating` and `reviews_count` on `books`. Recompute them
  with one aggregate query in the review's `after_save` and `after_destroy`, inside the same
  transaction, so no read after commit sees a stale average. Bump `updated_at` at the same
  time.
- **Alternatives considered**: Computing the aggregate at read time (sorting 10k books by a
  subquery is slow); `counter_cache` (covers the count but not the average).

## R10. Caching strategy (Principle IX)

- **Decision**:
  - All reads go through `Rails.cache.fetch` with version-aware keys (see the cache table
    in [data-model.md](data-model.md)).
  - **Catalog**: key on `Book.catalog_version` (count plus `max(updated_at)`). Every
    catalog-affecting write bumps a book's `updated_at` through `touch:` or an explicit
    `touch_all`.
  - **Per-user data**: library, shelves, placements, positions, bookmarks and notes all
    touch the owning `User`. Keys embed `user.cache_key_with_version`. `Current.user` is
    already loaded per request, so the version costs no extra query.
  - **Book-scoped data** (reviews, conversions, description) keys on
    `book.cache_key_with_version`.
  - **Tests**: the test environment keeps `:null_store`. Cache specs opt in with a
    `:caching` tag that swaps in an `ActiveSupport::Cache::MemoryStore`. A query-counter
    helper proves the hit path and the invalidation path.
- **Rationale**: Version-in-key means a write never has to find and delete entries, so
  there is no delete-versus-repopulate race. Correctness comes from the key changing in the
  same transaction as the write.
- **Exception**: Authentication lookups (session by cookie, user by email for sign-in, and
  lockout state) always read the database. See Complexity Tracking in the plan.
- **Alternatives considered**: Delete-on-write keys (racy); fragment caching (forbidden by
  Principle IX).

## R11. Personal library structure (FR-027–FR-035)

- **Decision**:
  - A `libraries` row per user owns entries and shelves. It gives one place for the touch
    chain and one owner check.
  - `shelves.kind` (favorites/custom) with a partial unique index guarantees exactly one
    Favorites shelf per library.
  - Shelf membership is a join (`shelf_placements`) on library entries, not on books, so
    removing an entry removes its placements automatically.
- **Alternatives considered**: Entries keyed directly on the user (no natural parent to
  touch); a boolean `favorite` on entries (Favorites would be a special case instead of a
  shelf).

## R12. Conversions (FR-049–FR-051)

- **Decision**:
  - A `conversions` row per `(book, source_checksum, target_format)`, where the checksum is
    the book file blob's checksum. It holds the status machine and the output attachment.
  - Replacing the book file destroys conversions with a different checksum, which purges
    their outputs.
  - The engine (job, tooling, output validation) belongs to the conversion feature.
    `request!` is idempotent through the unique index.
- **Alternatives considered**: Keying on blob id (a re-upload of identical bytes would
  convert again); per-user conversions (duplicate work for identical output).

## R13. Deletion strategy (FR-022, account deletion)

- **Decision**: Use `dependent: :destroy` everywhere, plus plain foreign keys (no
  `ON DELETE CASCADE`). Conversions use `dependent: :nullify` for `requested_by`. Rating
  refresh is skipped when the book itself is being destroyed.
- **Rationale**: Callbacks must run, because touches keep caches correct and attachments
  must be purged. Database cascades would bypass both.
- **Alternatives considered**: DB cascades (orphaned files, stale caches); soft delete
  (archive already covers the non-destructive case).

## R14. Name rule: required at sign-up, optional otherwise (FR-005)

- **Decision**: The column defaults to `""`. Presence is validated only in a custom
  `:sign_up` context; Rails 7.1+ accepts multiple contexts:
  `save(context: [:create, :sign_up])`. On update, a non-blank name cannot become blank.
  Maintainer-created accounts may stay nameless.
- **Alternatives considered**: A nullable name with a database default of NULL (two kinds of
  "empty"); always requiring it (breaks maintainer-seeded admins).

## R15. Testing approach (Principle II)

- **Decision**:
  - Model specs for every model, validator and rule, using shoulda-matchers for
    associations and validations and explicit examples for callbacks, state machines and
    lockout.
  - Request specs for sign-in (lockout, normalization, generic alert), password reset
    (unlocks) and Active Storage auth.
  - One system spec for the sign-in lockout flow, run at a mobile viewport (390×844) first,
    then desktop (1440×900).
  - Small fixture files in `spec/fixtures/files/`: a PDF, a reflowable EPUB, a CBZ, a
    CBR-signature file, a DOCX renamed to `.pdf`, and JPEG/PNG/WebP/GIF covers.
  - Live verification with Playwright MCP covers the sign-in lockout. Data-only tasks are
    verified with the `bin/rails runner` scenarios in [quickstart.md](quickstart.md); see
    Complexity Tracking.

## Sources

- [Rapid7: CVE-2026-33173 analysis (direct uploads skip identification)](https://rapid7.com/blog/post/ra-kindarails2shell-technical-analysis-cve-2026-66066)
- [OSV: CVE-2026-33173](https://api.osv.dev/v1/vulns/CVE-2026-33173)
- [active_storage_validations](https://github.com/aryrabelo/active_storage_validations)
- [Rails API: ActiveStorage::Blobs::RedirectController](https://edgeapi.rubyonrails.org/classes/ActiveStorage/Blobs/RedirectController.html)
- [Saeloun: Rails 7 expiring Active Storage URLs](https://blog.saeloun.com/2021/09/14/rails-7-adds-expiring-urls-to-active-storage)
- [37signals: Announcing Lexxy](https://dev.37signals.com/announcing-lexxy-a-new-rich-text-editor-for-rails/)
- [Saeloun: Lexxy editor](https://blog.saeloun.com/2025/10/14/lexxy-editor/)
