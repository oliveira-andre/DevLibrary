# Implementation Plan: Home Page, Book Page and Reader

**Branch**: `002-home-and-reader` (spec-kit feature id. Work is currently on `main`; no git
branch was created) | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-home-and-reader/spec.md`

## Summary

DevLibrary's first screens, built on the 001 data model:

- **Home**: a centered search box, a "Your collection" row ordered by last read that opens
  straight into the reader, and the newest books 50 at a time with keyset-paged "See more".
- **Search results** with category and sort dropdowns.
- **Book page**: cover, title, description, rating summary, reviews (20 at a time), an inline
  review form with Trix and an emoji picker, edit in the app-wide modal, plus collection
  and heart controls.
- **Reader**: opens at the account's saved position, saves every turn through a retrying
  outbox, and turns pages with a 250 ms slide that the person can switch off. The setting
  is saved on the account.

It also lays down the shared look from `DESIGN.md` (tokens, fonts, nav, buttons, cards,
modal) and enables the PWA manifest.

Added by the 2026-10-20 clarify session:
- **Sign-up** in a branded `auth` layout shared with sign-in and password reset (R15).
- **Logos** in the header, on the auth pages, and as the favicon, app and home-screen
  icons, derived from `app/assets/images` by a script (R16).
- **Link previews**: branded everywhere, book-specific for published books. This needs a
  constitution amendment (R17).
- **Account protection as in DevCine and Spotsby**: a per-email sign-in bucket with a
  generic response, blocked accounts, and a lock email (R18).

Key technical choices (from [research.md](research.md)):
- foliate-js for EPUB. An in-house fixed-layout pager over pdf.js 6.4.299 and zip.js
  2.23.0 for PDF and CBZ. Both read by `Range`, so a 500 MB PDF never downloads in full
  (R1).
- CBR reading deferred, with a clear in-reader message (R2).
- Turbo Stream "See more": keyset for the newest list, offset plus `dom_id` dedupe for
  search (R3).
- A Web Animations slide (fixed-layout) and foliate's `animated` slide (EPUB). Instant when
  the setting is off or reduced motion is on (R4).
- A single-entry `keepalive` position outbox with retry, and JSON 401s when signed out (R5).
- A session-authorized, range-capable file streaming endpoint (R6).
- Reading settings as three `users` columns (R7).

The design is in [data-model.md](data-model.md). The interfaces are in
[contracts/http.md](contracts/http.md) and [contracts/reader-client.md](contracts/reader-client.md).

## Technical Context

**Language/Version**: Ruby 3.4.7, Rails 8.1.4. JavaScript as native ES modules (ES2022)
through importmap, with no build step.

**Primary Dependencies**:
- Already installed: turbo-rails 2.0.23 (Turbo 8.0.23), Stimulus, Action Text with Trix
  2.1.19, Active Storage with image_processing and libvips 8.18, Solid Cache, Solid Queue.
- **Vendored JavaScript (new)**: foliate-js @ `78914ae`, pdfjs-dist 6.4.299,
  @zip.js/zip.js 2.23.0, emoji-picker-element 1.29.1 with emoji-picker-element-data 1.8.0.
- **Assets (new)**: Hanken Grotesk and Inter WOFF2 (OFL), Lucide SVG icons (ISC).
- **No new gems.**

**Storage**: PostgreSQL. Two migrations: reading settings on `users`, and `users.blocked_at`. Active Storage
Disk service. The `:card` and `:large` cover variants are preprocessed by Active Job.
`Rails.cache` is as in 001 (Solid Cache in production; MemoryStore for `:caching` specs).

**Testing**:
- RSpec with shoulda-matchers, FactoryBot and FFaker.
- Capybara + Selenium headless Chrome. Mobile runs first with Chrome mobile emulation
  (390×844, touch), then desktop (1440×900).
- CDP for offline and reduced-motion emulation.
- Playwright MCP for live checks.
- New multi-page reader fixtures from `script/generate_spec_fixtures.rb`.

**Target Platform**: Linux server in Docker via Kamal. Clients: `allow_browser versions:
:modern` (pdf.js 6 floor: Chrome 125, Safari 18, Firefox ESR), the installable PWA, and
Hotwire Native later.

**Project Type**: Rails monolith web application.

**Performance Goals**:
- Home and each "See more" p95 < 1 s at 10,000 books (SC-001).
- Instant page change < 100 ms, slide finishes ≤ 250 ms (SC-004).
- A 500 MB PDF shows its saved page in < 5 s (SC-005).
- A posted review appears with the updated average in < 1 s (SC-007).

**Constraints**:
- Engines load only on the reader page and only for the book's format (`preload: false`).
- No binaries in `Rails.cache`.
- No full-file download for PDF and CBZ.
- No decoration on the reading surface.
- Touch targets ≥ 44 px.
- Never run generators that overwrite the custom `spec/rails_helper.rb` and
  `spec/spec_helper.rb`.

**Scale/Scope**:
- 10k books and thousands of users.
- 2 migrations, 15 controllers, 2 new query objects plus 5 model methods, 1 new concern
  (`User::Blockable`), 1 mailer action.
- About 40 views and partials, 4 layouts, 8 Stimulus controllers, 6 reader modules.
- 8 system spec files and 15 request spec files.

No NEEDS CLARIFICATION items remain. All were resolved in research.md (R1–R18).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution v1.1.0. ✅ = pass, ➖ = not applicable to this feature, ⚠ = justified
deviation (see Complexity Tracking).

| # | Gate (Principle) | Pre-research | Post-design | Evidence |
|---|---|---|---|---|
| 1 | Turbo/Hotwire strategy (I) | ✅ | ⚠ | Turbo Streams drive See more, reviews, library controls, direction and settings. Review edit uses the app-wide `<dialog>` modal (R9). Reader engines fall under the exception: pinned, Stimulus-wrapped, content only. Two justified deviations: the emoji picker widget and the position outbox |
| 2 | RSpec model, request and system specs (II) | ✅ | ✅ | Model specs for every new query and concern, with `:caching` examples. One request spec per controller with negative auth. Six system specs per story (R14) |
| 3 | Playwright MCP live verification (II) | ✅ | ✅ | Every task ends with the [quickstart.md](quickstart.md) §4 run, mobile then desktop, with screenshots |
| 4 | Mobile first, then desktop (III) | ⚠ | ⚠ | Chrome mobile emulation with touch runs first in specs and live checks. PWA manifest enabled. Tap, swipe and pinch on touch; arrows and page keys on desktop (R11, R12). There is no Hotwire Native app to verify |
| 5 | DESIGN.md and `shared/` tokens (IV) | ✅ | ✅ | Tokens, fonts, buttons, cards, nav, modal and reader themes live in `shared/`. Page CSS is loaded per page. The reading surface uses only theme tokens (R10, FR-030) |
| 6 | Reading position persistence (V) | ✅ | ⚠ | Saved on every `relocate` through the outbox. Retries cover offline, unload, Turbo navigation and an expired session. Server newest-wins. Resume from the server or a newer outbox entry, with dedicated system specs (R5). CBR does not open in-app yet (R2) |
| 7 | Reflowable, fixed-layout and RTL fixtures (II, VI) | ✅ | ✅ | Multi-page PDF, 3-chapter EPUB, CBZ comic, RTL manga CBZ. Direction switch saved per book. EPUB text size and theme. Fixed-layout zoom and pan. RTL-mirrored taps, keys and slide |
| 8 | Content validation, immutable originals, conversion rules (VII) | ➖ | ➖ | No uploads or conversions in this feature. The file endpoint streams the original read-only |
| 9 | Sign-in required, admin-only, private data (VIII) | ✅ | ⚠ | Every route requires a session, and JSON requests get 401. Blocked sessions die on their next request (403 for JSON). Two sign-in rate buckets plus the 001 lockout. Admin review deletion has negative specs for non-admins. Personal data is always resolved through `Current.user`. Book bytes go only through the authorized streaming endpoint (`private, no-store`). **Book link previews need the Principle VIII amendment**: tasks for US9 are blocked until it is ratified (R17) |
| 10 | Cached reads and automatic invalidation, tested both ways (IX) | ✅ | ⚠ | Five new version-keyed reads, invalidated by the existing touch chains (data-model cache table), each tested for hit and invalidation. Reading settings come from the already-loaded `Current.user` |

**Result**: PASS. Six deviations are recorded below. The sixth, signed-out book previews,
needs the Principle VIII amendment ratified before its tasks run.

## Project Structure

### Documentation (this feature)

```text
specs/002-home-and-reader/
├── spec.md              # Feature spec (created in this run; no spec existed)
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R14
├── data-model.md        # Phase 1: users settings columns, query objects, cache keys
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   ├── http.md          # routes, formats, Turbo targets, authorization
│   └── reader-client.md # reader shell, engine adapter, input, animation, outbox
├── checklists/
│   └── requirements.md  # spec quality checklist
└── tasks.md             # Phase 2 (/speckit-tasks; not created here)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   ├── concerns/
│   │   ├── authentication.rb          # + 401 for JSON signed out, blocked sessions, redirect_if_authenticated (R5, R18)
│   │   └── book_scoped.rb             # set_book via find_visible_cached!, 404 "not available"
│   ├── sessions_controller.rb         # + email bucket, generic throttle response, auth layout (R18)
│   ├── registrations_controller.rb    # sign-up (R15)
│   ├── passwords_controller.rb        # auth layout only
│   ├── home_controller.rb             # search box, collection row, first 50 newest
│   ├── recent_books_controller.rb     # See more (turbo_stream)
│   ├── books_controller.rb            # index = search results, show = book page
│   ├── reviews_controller.rb          # edit (modal), update, destroy
│   ├── reading_settings_controller.rb # edit (modal / reader panel), update
│   └── books/
│       ├── readers_controller.rb      # reader shell
│       ├── files_controller.rb        # ActiveStorage::Streaming, Range (R6)
│       ├── reading_positions_controller.rb
│       ├── reading_directions_controller.rb
│       ├── library_entries_controller.rb
│       ├── favorites_controller.rb
│       ├── preview_images_controller.rb # public, published only (R17)
│       └── reviews_controller.rb      # index (See more), create
├── mailers/
│   └── passwords_mailer.rb            # + locked(user) (R18)
├── models/
│   ├── user.rb                        # include ReadingSettings, Blockable
│   ├── user/reading_settings.rb       # R7
│   ├── user/blockable.rb              # blocked_at, block!, unblock! (R18)
│   ├── user/lockable.rb               # + blocked handling, lock email (R18)
│   ├── book.rb                        # cover variants (+ :preview), find_visible_cached!, search_page, published_preview
│   ├── book/recent.rb                 # keyset newest list (R3)
│   ├── book/page.rb                   # Data.define(:books, :next_params)
│   ├── library.rb                     # + state_for(book)
│   └── review.rb                      # + Review.by(user, book:)
├── helpers/
│   ├── covers_helper.rb               # cover_image_tag with hour-window signed URLs (R13)
│   ├── icons_helper.rb                # inline Lucide SVG
│   ├── link_preview_helper.rb         # og/twitter meta (R17)
│   └── ratings_helper.rb              # stars, average display
├── views/
│   ├── layouts/application.html.erb   # nav (wordmark left), flash, modal dialog, shared CSS, icons, manifest, preview meta
│   ├── layouts/auth.html.erb          # centered card + large wordmark (R15, R16)
│   ├── layouts/preview.html.erb       # signed-out book preview (R17)
│   ├── layouts/reader.html.erb        # chrome-free reading layout
│   ├── layouts/_head_icons.html.erb   # favicon, apple-touch, manifest links
│   ├── sessions/new, registrations/new, passwords/{new,edit}   # restyled in the auth layout
│   ├── passwords_mailer/locked.{html,text}.erb                # R18
│   ├── books/previews/show.html.erb   # R17
│   ├── shared/                        # _nav, _modal, _search_form, _book_card, _cover, _see_more, _empty_state
│   ├── home/                          # show, _collection
│   ├── recent_books/                  # index.html, index.turbo_stream
│   ├── books/                         # index (+ .turbo_stream), show, not_available, _library_controls, _rating_summary
│   ├── books/readers/                 # show, _preferences, _toolbar, _settings_panel
│   ├── books/reviews/                 # _form, _review, _own_review, index/create .turbo_stream
│   ├── reviews/                       # edit, update/destroy .turbo_stream
│   └── reading_settings/              # edit, _form, update.turbo_stream
├── javascript/
│   ├── controllers/                   # modal, auto_submit, scroll_row, emoji_picker, star_input,
│   │                                  # reader, reader_preferences, reader_settings_panel
│   └── reader/
│       ├── engines/reflowable.js      # foliate-js adapter
│       ├── engines/fixed_layout.js    # pager: slide, zoom/pan, RTL, pre-render
│       ├── sources/pdf_source.js      # pdf.js, range loading
│       ├── sources/cbz_source.js      # zip.js HttpRangeReader
│       ├── input.js                   # tap zones, swipe, keys → logical moves
│       └── outbox.js                  # position outbox (R5)
└── assets/
    ├── fonts/                         # Hanken Grotesk, Inter (WOFF2)
    ├── images/brand/                  # wordmark-64.{webp,png}, wordmark-160.{webp,png} (R16)
    ├── images/icons/                  # Lucide SVGs
    └── stylesheets/
        ├── shared/                    # tokens, fonts, base, buttons, cards, forms, nav, modal, stars, reader_themes, auth
        └── pages/                     # home, books, reader, preview
public/
├── favicon.ico, icon.png, icon-192.png, icon-maskable.png, apple-touch-icon.png, og-image.png   # R16, R17 (icon.svg removed)
└── vendor/
    ├── foliate-js/78914ae/
    ├── pdfjs-dist/6.4.299/            # build/ + cmaps, standard_fonts, wasm, iccs
    └── emoji-picker-element/1.29.1/   # index.js, picker.js, database.js, data.json
vendor/javascript/@zip.js--zip.js@2.23.0.js
config/
├── routes.rb                          # contracts/http.md
└── importmap.rb                       # contracts/reader-client.md §8
db/
├── migrate/…_add_reading_settings_to_users.rb
├── migrate/…_add_blocked_at_to_users.rb
└── seeds.rb                           # + 120 books, reviews, reader collection and positions, reader fixtures
script/
├── generate_brand_assets.rb           # icons, wordmarks, og-image from app/assets/images (R16)
├── generate_spec_fixtures.rb          # + reader fixtures (R14)
├── generate_large_pdf.rb              # SC-005, on demand, never committed
└── benchmark_home.rb                  # SC-001
spec/
├── fixtures/files/reader/             # text-6-pages.pdf, reflowable-3-chapters.epub, comic-4-pages.cbz, manga-rtl-4-pages.cbz
├── support/
│   ├── system_viewports.rb            # + Chrome mobile emulation (touch) for :mobile
│   └── reader_helpers.rb              # wait for data-reader-state, turn, offline, reduced motion
├── models/                            # book/recent_spec, user/reading_settings_spec, + additions to book, library, review specs
├── requests/                          # one per controller (contracts/http.md "Required tests")
└── system/                            # home, search, book_page, reader, reader_persistence, page_animation, sign_up_and_branding, account_protection
```

**Structure Decision**:
- A single Rails monolith using standard directories.
- Book-scoped actions are singular nested resources under `Books::` controllers, so each
  one has a small controller and a clear authorization point (`BookScoped`).
- Reader JavaScript lives in `app/javascript/reader/` as plain modules behind one Stimulus
  controller. Engines are loaded with `import()`.
- Third-party engines that load sibling files sit in versioned `public/vendor/` folders
  and are pinned by absolute path (R1).
- Stories ship in priority order, each independently testable:
  1. the shared shell (layout, tokens, nav, modal);
  2. US1 newest list, then US2 collection row;
  3. US3 reader, then US4 animation;
  4. US5 book page and reviews, then US6 search;
  5. US7 collection and heart controls;
  6. US8 sign-up, branding and account protection;
  7. US9 link previews, once the constitution amendment is ratified.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Gate 4: no Hotwire Native verification. Mobile is verified with Chrome mobile emulation and the PWA | No Hotwire Native app exists yet | Building a native shell only to test it is a separate project. Emulation with touch exercises the same Turbo views, tap, swipe and pinch |
| Gate 6 (Principles V, VII): CBR books show "can't be opened in the reader yet" instead of opening (R2) | Reading RAR in the browser needs the whole file in WebAssembly memory (500 MB), from libraries idle since 2023–24 with an unpatched RAR CVE. Doing it on the server needs a job pipeline, derived page storage and a ruling on whether a page cache is a "conversion" | Shipping libarchive.js now risks memory blow-ups and a known CVE. No CBR can enter the catalog yet (no upload screen, none seeded), so deferring loses no reader-facing capability today |
| Gate 1 (Principle I): emoji-picker-element, a compiled web component, used outside the reader-engine exception (R8) | The request asks for emoji in reviews. Search, skin tones and keyboard and screen-reader support matter on desktop, where there is no emoji keyboard | A curated Stimulus picker has no search. The OS picker is undiscoverable on desktop. The widget holds no application state, is lazy-loaded inside a Stimulus controller, and only inserts text into Trix |
| Gate 1 (Principle I): the position outbox keeps one unsent write in `localStorage` (R5) | Principle V forbids losing a position on unload, offline or session expiry, including when the tab closes while offline | Memory only loses the write when the tab closes. Server only cannot save while offline. The entry is cleared on the server's 204, and the server stays the source of truth (newest wins) |
| Gate 9 (Principle VIII): a signed-out `GET /books/:id` for a published book returns a 200 preview page, and `/books/:id/preview_image` is public (R17). **Pending amendment** | The person asked for book links to show the cover, title and author in WhatsApp, Slack, iMessage and Discord. Those apps fetch links without a session | A branded-only preview needs no exception, but was not chosen. Exposure is limited to title, authors and a resized cover of published books, through a struct that cannot load anything else. Drafts, archived and deleted books stay behind sign-in. US9 tasks start only after `/speckit-constitution` ratifies the amendment |
| Gate 10 (Principle IX): reading settings are read from `Current.user`, not `Rails.cache` (R7) | Authentication already loads the user row on every request (the 001 exception), and the settings are columns on it | Caching them would add a cache lookup to remove zero queries. Invalidation still works, because every change bumps `users.updated_at`, which per-user keys embed |
