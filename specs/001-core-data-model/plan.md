# Implementation Plan: Core Data Model

**Branch**: `001-core-data-model` (spec-kit feature id. Work is currently on `main`; no git
branch was created) | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-core-data-model/spec.md`

## Summary

Build DevLibrary's data foundation: 13 tables plus Action Text storage, their models,
associations, validations, callbacks and query entry points. Also harden the existing
Rails 8 sign-in with per-account lockout. Screens are out of scope. The design is in
[data-model.md](data-model.md). The surface that later features rely on is in
[contracts/domain-api.md](contracts/domain-api.md). The only HTTP behavior that changes is
in [contracts/sign-in.md](contracts/sign-in.md).

Key technical choices (from [research.md](research.md)):
- String-backed enums with check constraints.
- `pg_trgm` search over a normalized `search_text` column.
- Files validated by their bytes with Marcel, not by name or declared type.
- Lockout counters under a row lock.
- Newest-wins reading positions.
- Version-keyed `Rails.cache` reads, with invalidation through touch chains.
- `dependent: :destroy` everywhere, so callbacks always run.

## Technical Context

**Language/Version**: Ruby 3.4.7, Rails 8.1.4

**Primary Dependencies**: Already installed: Turbo 2.0.23, Stimulus 1.3.4, Active Storage
(installed) with Marcel 1.2.1, image_processing 1.14, Solid Cache 1.0.10, Solid Queue.
Added from Rails itself: Action Text (`action_text:install`). Database extension: `pg_trgm`.
**No new gems.**

**Storage**: PostgreSQL (UTF-8, so emoji are stored natively). Active Storage Disk service
in dev and prod for now. `Rails.cache`: Solid Cache in production, memory store in
development, null store in test (cache specs swap in a MemoryStore).

**Testing**: RSpec 8.0.4, shoulda-matchers 8.0.1, FactoryBot 6.5.1, FFaker, Capybara 3.40
and Selenium 4.51 (system specs at mobile 390×844, then desktop 1440×900), Playwright MCP
live checks.

**Target Platform**: Linux server in Docker via Kamal. Clients: responsive web, PWA,
Hotwire Native.

**Project Type**: Rails monolith web application.

**Performance Goals**: Catalog search p95 < 1 s at 10,000 books (SC-007). A reading
position save is one locked single-row write plus one user touch.

**Constraints**:
- Book files ≤ 500 MB; covers ≤ 10 MB (JPEG, PNG, WebP).
- No binaries in `Rails.cache`.
- No permanent public file URLs.
- Failure responses must not reveal whether an account exists or is locked.

**Scale/Scope**: About 10k books and thousands of users. 13 new or extended tables, 13
models, 2 validators, 1 initializer, 2 small controller adjustments, and the root route.

No NEEDS CLARIFICATION items remain. All were resolved in research.md (R1–R15).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v1.1.0. ✅ = pass, ➖ = not applicable to this feature, ⚠ = justified
deviation (see Complexity Tracking).

| # | Gate (Principle) | Pre-research | Post-design | Evidence |
|---|---|---|---|---|
| 1 | Turbo/Hotwire strategy (I) | ➖ | ➖ | No new UI. The sign-in form is unchanged apart from its flash message |
| 2 | RSpec model, request and system specs (II) | ✅ | ✅ | Model specs for every model and validator. Request specs for sign-in, reset and file access. A system spec for lockout (R15) |
| 3 | Playwright MCP live verification (II) | ⚠ | ⚠ | Live check covers sign-in lockout and file access. Data-only tasks are verified with console scenarios (quickstart §3) |
| 4 | Mobile first, then desktop (III) | ✅ | ✅ | The lockout system spec and live check run at 390×844 first, then 1440×900 |
| 5 | DESIGN.md and `shared/` tokens (IV) | ➖ | ➖ | No styling changes |
| 6 | Reading position persistence (V) | ✅ | ✅ | `ReadingPosition.record!` is newest-wins and clamps future times. The position survives library removal and is saved without a library entry |
| 7 | Reflowable, fixed-layout and RTL fixtures (II, VI) | ✅ | ✅ | `kind` and `reading_direction` with manga defaulting to RTL and a per-user override. Fixtures include EPUB, PDF, CBZ and a manga CBZ |
| 8 | Content validation, immutable originals, conversion rules (VII) | ✅ | ✅ | Byte-sniffing validators. Conversions are separate attachments, unique per checksum and format, PDF/EPUB only, and purged on file replacement. The engine and output validation belong to the conversion feature |
| 9 | Sign-in required, admin-only, private data (VIII) | ✅ | ✅ | Active Storage routes require a session. `admin?` predicate. Private records are scoped by `user`/`library`. Lockout plus the IP limit. Admin endpoints arrive with later features and must carry negative specs |
| 10 | Cached reads and automatic invalidation, tested both ways (IX) | ⚠ | ⚠ | Version-keyed reads per the data-model cache table, with touch chains. Authentication lookups are not cached |

**Result**: PASS. Two justified deviations are recorded below.

## Project Structure

### Documentation (this feature)

```text
specs/001-core-data-model/
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R15
├── data-model.md        # Phase 1: tables, rules, state machines, cache map
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   ├── sign-in.md       # HTTP behavior changes
│   └── domain-api.md    # model-level API for later features
├── checklists/
│   └── requirements.md  # spec quality checklist
└── tasks.md             # Phase 2 (/speckit-tasks; not created here)
```

### Source Code (repository root)

```text
app/
├── models/
│   ├── user.rb                    # extended: name, role, lockout, library callback
│   ├── category.rb
│   ├── categorization.rb
│   ├── book.rb
│   ├── book/search.rb             # query object behind Book.search (R4)
│   ├── library.rb
│   ├── library_entry.rb
│   ├── shelf.rb
│   ├── shelf_placement.rb
│   ├── reading_position.rb
│   ├── bookmark.rb
│   ├── note.rb
│   ├── review.rb
│   ├── conversion.rb
│   └── concerns/
│       └── search_normalizable.rb # Latin-diacritic-insensitive normalization (R4)
├── validators/
│   ├── book_file_validator.rb     # R2
│   └── cover_image_validator.rb   # R2
└── controllers/
    ├── sessions_controller.rb     # uses User.authenticate_with_lockout
    └── passwords_controller.rb    # shows the real validation error
config/
├── routes.rb                      # placeholder root → sessions#new
├── application.rb                 # active_storage.urls_expire_in = 1.hour
└── initializers/
    └── active_storage_authentication.rb   # R3
db/
├── migrate/                       # pg_trgm, action_text, one migration per table, users extension
└── seeds.rb                       # admin, readers, categories, sample books (quickstart §3)
spec/
├── factories/                     # one per model
├── fixtures/files/                # sample.pdf, sample.epub, sample.cbz, manga.cbz, sample.cbr, fake.pdf, covers
├── support/
│   ├── caching.rb                 # :caching tag → MemoryStore
│   ├── query_counter.rb           # proves cache hits run no SQL
│   └── system_viewports.rb        # mobile/desktop drivers
├── models/                        # one spec per model + book/search_spec.rb
├── validators/
├── requests/                      # sessions, passwords, active_storage_access
└── system/
    └── sign_in_lockout_spec.rb    # mobile, then desktop
```

**Structure Decision**: A single Rails monolith using standard Rails directories. Query
objects live under the model namespace (`app/models/book/search.rb`), not in a separate
services layer. `test/` (Minitest scaffolding) is unused; all tests live in `spec/`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Gate 3: data-only tasks verified by console scenarios instead of Playwright MCP | Migrations, models and validations have no screen to drive in a browser | Building throwaway screens just to click through them would add UI that later features would replace, and still prove less than the model specs |
| Gate 10: authentication lookups (session by cookie, user by email at sign-in, lockout counters) read the database, not `Rails.cache` | A cached session or lockout state could keep a revoked session alive, or let attempts slip past a lock. Principle IX says correctness wins | Caching with delete-on-write leaves a race window on a security boundary. Version keys need the very row being looked up |
