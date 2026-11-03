# Requirement Coverage: Core Data Model

**Feature**: [spec.md](spec.md) · Supports SC-009 ("every rule in this spec has at least one
automated check")

Each functional requirement maps to the spec files and example groups that prove it. Some
rules can only be enforced by a screen that does not exist yet. Those rows say **Deferred**
and name the data or predicate this feature already provides.

| FR | Requirement (short) | Proven by |
|---|---|---|
| FR-001 | Email stored trimmed/lowercase, unique ignoring case | `spec/models/user_spec.rb` "email address" |
| FR-002 | Sign-in email trimmed/lowercased | `user_spec` "is matched regardless of case"; `spec/requests/sessions_spec.rb` "signs in … loosely"; `spec/system/sign_in_lockout_spec.rb` "differently-cased email" |
| FR-003 | Well-formed email | `user_spec` "must be well-formed" |
| FR-004 | Password 8–72 | `user_spec` "password" |
| FR-005 | Name: blank default, required at sign-up, can't be cleared, ≤ 100 | `user_spec` "name" |
| FR-006 | Role reader/admin, reader default | `user_spec` "role". **Deferred**: sign-up must not permit `role` (sign-up feature strong params) |
| FR-007 | Per-IP sign-in limit kept | `sessions_spec` "keeps the per-IP rate limit" |
| FR-008 | Per-account lockout, doubling, 24 h cap | `spec/models/user/lockable_spec.rb` "#register_failed_sign_in!"; `sessions_spec` "different IP" |
| FR-009 | Locked refuses the correct password | `lockable_spec` ".authenticate_with_lockout"; system spec |
| FR-010 | Success or password reset clears the lock | `lockable_spec` "resetting"; `spec/requests/passwords_spec.rb` |
| FR-011 | Identical failure messages | `sessions_spec` "identical responses" |
| FR-012 | Library + Favorites created with the account | `user_spec` "gets an empty library"; `spec/models/library_spec.rb` "is created with the account" |
| FR-013 | Title, authors, rich description, cover | `spec/models/book_spec.rb` validations, defaults, "emoji in the rich-text description" |
| FR-014 | Formats by content, size caps | `spec/validators/book_file_validator_spec.rb`, `spec/validators/cover_image_validator_spec.rb` |
| FR-015 | Content type | `book_spec` "defaults", "unknown kind" |
| FR-016 | Reading direction defaults, admin may change | `book_spec` "reading direction" |
| FR-017 | Draft/published/archived visibility | `book_spec` ".visible_to"; `spec/models/book/search_spec.rb` "never returns drafts or archived" |
| FR-018 | No publish without title and file | `book_spec` "refuses to publish without a book file" + title presence |
| FR-019 | Categories | `spec/models/category_spec.rb`, `spec/models/categorization_spec.rb` |
| FR-020 | Only admins manage catalog | **Deferred** to the admin catalog screens. `User#admin?` and `Book.visible_to` exist (`user_spec`, `book_spec`) |
| FR-021 | Stable public id | `book_spec` "public id" |
| FR-022 | Delete cascades | `book_spec` "removes everything that belongs to it when deleted" |
| FR-023 | Text search, accent/case-insensitive, partial | `search_spec` "matching" |
| FR-024 | Single category filter | `search_spec` "category filter" |
| FR-025 | Sort orders and defaults | `search_spec` "sorting", "defaults to relevance" |
| FR-026 | Text + category + sort combine | `search_spec` "combines with the search text" |
| FR-027 | Add published books, no duplicates | `library_spec` "#add!"; `spec/models/library_entry_spec.rb` |
| FR-028 | Remove keeps catalog book, position, notes, bookmarks | `library_spec` "#remove!"; `spec/models/reading_position_spec.rb` "survives removing" |
| FR-029 | Own shelves, unique names, Favorites reserved | `spec/models/shelf_spec.rb` |
| FR-030 | Favorites can't be renamed or deleted | `shelf_spec` "the Favorites shelf" |
| FR-031 | Many shelves per book; deleting a shelf keeps books | `library_spec` "shelves"; `shelf_spec` "keeps its books" |
| FR-032 | Heart toggle | `library_spec` "favorites" |
| FR-033 | Search/filter own library | `library_spec` "#search" |
| FR-034 | Cover, title and position for each library book | `library_spec` "carries the saved position". **Deferred**: the cover-over-title display (library screen) |
| FR-035 | Libraries/shelves private | `library_spec` "returns only this reader's entries"; `spec/models/shelf_placement_spec.rb` same-library rule. **Deferred**: per-request ownership checks in library controllers |
| FR-036 | One position per reader/book with location, %, time | `reading_position_spec` ".record!" |
| FR-037 | Saved without a library entry | `reading_position_spec` "not in the reader's library" |
| FR-038 | Older update never replaces newer | `reading_position_spec` "ignores an update stamped earlier", "clamps" |
| FR-039 | Per-reader direction override | `reading_position_spec` "reading direction override" |
| FR-040 | Bookmarks | `spec/models/bookmark_spec.rb` |
| FR-041 | Notes: rich text, required, ≤ 10,000 | `spec/models/note_spec.rb` |
| FR-042 | Notes private, never alter the book | `note_spec` ".for … only the author's", "never changes the book itself" |
| FR-043 | Notes in book order | `note_spec` ".for"; `bookmark_spec` ".for" |
| FR-044 | Reviews: rating 1–5, content, published only | `spec/models/review_spec.rb` "rating", "content", "published books" |
| FR-045 | One review per reader | `review_spec` "one review per reader". **Deferred**: only the author may edit/delete (review screens) |
| FR-046 | Admins delete any review | **Deferred** to the review screens. `User#admin?` exists, and `destroy` keeps averages right (`review_spec`) |
| FR-047 | Average and count always accurate | `review_spec` "the book's average rating and review count" |
| FR-048 | Download original | **Deferred** to the download endpoint. `Book.find_visible!` decides access (`book_spec`) |
| FR-049 | Request PDF/EPUB, one per file version | `spec/models/conversion_spec.rb` ".request!" |
| FR-050 | Status, requester, failure reason, retry | `conversion_spec` ".request!", "status transitions" |
| FR-051 | Original untouched; replaced file discards conversions | `conversion_spec` "discards conversions …", "keeps conversions …" |
| FR-052 | No permanent public file links | `spec/requests/active_storage_access_spec.rb`; `config.active_storage.urls_expire_in = 1.hour` |
| FR-053 | Share link = book's public id only | `book_spec` "shares only the book's own identifier" |
| FR-054 | Signed-out recipient returns after sign-in | `spec/requests/return_after_sign_in_spec.rb` |
| FR-055 | Draft/deleted unavailable; archived only for keepers | `book_spec` ".find_visible! (share links)" |
| FR-056 | Full Unicode/emoji everywhere | `user_spec` "keeps emoji intact"; `shelf_spec` "keeps emoji"; `book_spec` description emoji; `note_spec`/`review_spec` emoji content |

**Summary**: 56 requirements. 49 are fully proven by automated examples. FR-020, FR-046
and FR-048 depend entirely on future screens. FR-006, FR-034, FR-035 and FR-045 are proven
at the data level, with a screen-level part deferred.
