# Quickstart: Validating the Core Data Model

**Feature**: [spec.md](spec.md) · **Data**: [data-model.md](data-model.md) ·
**Contracts**: [sign-in.md](contracts/sign-in.md), [domain-api.md](contracts/domain-api.md)

Use this after implementation to prove the feature works. It is a run guide, not code.

## Prerequisites

- PostgreSQL running locally, with the `pg_trgm` contrib extension available (it ships with
  standard Postgres).
- Ruby 3.4.7 and `bundle install` done.
- Chrome installed (Selenium system specs) and the Playwright MCP available for the live
  check.

## 1. Schema

```sh
bin/rails db:prepare
bin/rails db:migrate:status        # every migration "up"
bin/rails runner 'puts ActiveRecord::Base.connection.extension_enabled?("pg_trgm")'   # => true
```

**Expected**: tables for users (extended), categories, categorizations, books, libraries,
library_entries, shelves, shelf_placements, reading_positions, bookmarks, notes, reviews,
conversions and action_text_rich_texts. `db/schema.rb` shows the check constraints and
unique indexes listed in data-model.md.

## 2. Automated suite

```sh
bundle exec rspec spec/models spec/validators   # data rules
bundle exec rspec spec/requests                 # sign-in, password reset, file access
bundle exec rspec spec/system                   # sign-in lockout, mobile then desktop
bundle exec rspec                               # everything, must be green
```

**Expected**: 0 failures. Every FR in the spec maps to at least one example (SC-009).

## 3. Console scenarios (data-only verification)

Run in `bin/rails console` against the development database after `bin/rails db:seed`. The
seeds include one admin, one reader, two categories and one published PDF, EPUB and manga
CBZ.

| # | Scenario | Expected |
|---|---|---|
| 1 | Create a user with email `" Ana@Example.COM "` in the `:sign_up` context without a name | invalid: name required |
| 2 | Same, with a name | saved. Email `ana@example.com`. `user.library.shelves` = [Favorites] |
| 3 | Call `User.authenticate_with_lockout` 5× with a wrong password, then with the correct one | last call returns `nil`. `locked?` true. `locked_until` ≈ now + 15 min |
| 4 | `travel` 16 min, fail 5× again | `locked_until` ≈ now + 30 min |
| 5 | Reader: `library.favorite!(manga)` then `library.remove!(manga)` | entry gone, placements gone, catalog book still present |
| 6 | `ReadingPosition.record!` at `read_at: 5.minutes.ago`, then at `9.minutes.ago` (use past times: anything over a minute in the future is clamped to now) | stored position is the first (newer) one |
| 7 | Create a manga book with no direction given | `reading_direction == "rtl"` |
| 8 | Attach a `.docx` renamed to `.pdf` as a book file | invalid: unsupported or unreadable file |
| 9 | Review with rating `"3.5"` | invalid. Rating `4` → book `average_rating` 4.0, `reviews_count` 1 |
| 10 | `Conversion.request!` for EPUB→PDF twice | same record both times |
| 11 | `Book.search(query: "cafe")` with a published "Café Noir" | returned |

## 4. Live verification (Playwright MCP)

1. Start the server: `bin/dev`.
2. **Mobile first**: set the viewport to 390×844 and open `/session/new`.
3. Sign in five times as the seeded reader with a wrong password, then once with the right
   one. **Expected**: every attempt shows "Try another email address or password." and the
   sixth does not sign in.
4. Request `/rails/active_storage/blobs/redirect/<any signed id>/x` while signed out.
   **Expected**: lands on the sign-in page.
5. Repeat steps 2–3 at **desktop** 1440×900 with a second seeded reader.
6. Sign in with an unlocked account using `"  READER@example.com "`. **Expected**: signed in.

## 5. Cache behavior

```sh
bundle exec rspec --tag caching
```

**Expected**: for every cached read in data-model.md, one example proves a repeat read runs
no SQL, and one proves the related write changes the result.
