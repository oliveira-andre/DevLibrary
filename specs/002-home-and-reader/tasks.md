---

description: "Task list for 002: Home Page, Book Page and Reader"
---

# Tasks: Home Page, Book Page and Reader

**Input**: Design documents from `specs/002-home-and-reader/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md) (R1–R18),
[data-model.md](data-model.md), [contracts/http.md](contracts/http.md),
[contracts/reader-client.md](contracts/reader-client.md), [quickstart.md](quickstart.md)

**Tests**: **REQUIRED.** Constitution Principle II overrides the template default. Every
story writes its RSpec specs first and makes sure they fail, then implements. Each story
ends with a Playwright MCP live check, mobile (390×844) first, then desktop (1440×900).

**Organization**: Tasks are grouped by user story, so each story can be built, tested and
demonstrated on its own.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: The user story the task belongs to (US1–US9 in spec.md)
- Paths are relative to the repository root (a Rails monolith, see plan.md)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Vendored libraries, fonts, icons, brand assets, fixtures and test support
that later phases rely on.

- [X] T001 [P] Vendor foliate-js at commit `78914aef4466eb960965702401634c2cb348e9b1` into `public/vendor/foliate-js/78914ae/` (R1).
  - Download `https://github.com/johnfactotum/foliate-js/archive/78914aef4466eb960965702401634c2cb348e9b1.tar.gz` into the scratchpad.
  - Copy every top-level `*.js` file, the `vendor/` directory and `LICENSE`, unmodified.
  - Do not use the third-party npm package `foliate-js@1.0.1`.
- [X] T002 [P] Vendor pdfjs-dist **6.4.299** into `public/vendor/pdfjs-dist/6.4.299/` (R1).
  - Get it with `npm pack pdfjs-dist@6.4.299` in the scratchpad.
  - Copy `build/pdf.min.mjs`, `build/pdf.worker.min.mjs`, `cmaps/`, `standard_fonts/`, `wasm/`, `iccs/` and `LICENSE`.
  - Keep the `.mjs` names. Files in `public/` are served by `Rack::Files`, which maps `.mjs` to JavaScript.
- [X] T003 [P] Vendor @zip.js/zip.js **2.23.0**'s self-contained root `index.min.js` as `vendor/javascript/@zip.js--zip.js@2.23.0.js` (R1, reader-client §8).
- [X] T004 [P] Vendor emoji-picker-element **1.29.1** into `public/vendor/emoji-picker-element/1.29.1/` (R8).
  - Files: `index.js`, `picker.js`, `database.js`, `LICENSE`.
  - Add emoji-picker-element-data **1.8.0** `en/emojibase/data.json` as `public/vendor/emoji-picker-element/1.29.1/data.json`.
- [X] T005 Add the pins from contracts/reader-client.md §8 to `config/importmap.rb` (depends on T001–T004).
  - Pins: `foliate-js/view`, `pdfjs-dist`, `pdfjs-dist/worker`, `@zip.js/zip.js`, `emoji-picker-element`, and `pin_all_from "app/javascript/reader", under: "reader"`.
  - Every engine pin uses `preload: false`.
  - Verify `bin/importmap json` lists them.
  - Verify `curl -sI http://localhost:3000/vendor/pdfjs-dist/6.4.299/build/pdf.min.mjs` shows a JavaScript `Content-Type`.
- [X] T006 [P] Add self-hosted WOFF2 fonts to `app/assets/fonts/`, with each family's `OFL.txt` (R10).
  - Hanken Grotesk 700 and 800.
  - Inter 400, 500 and 600.
  - Latin and Latin-Extended subsets.
- [X] T007 [P] Add Lucide (ISC) SVG icons to `app/assets/images/icons/` with `LICENSE` (R10).
  - Icons: `search`, `heart`, `star`, `settings`, `chevron-left`, `chevron-right`, `arrow-left`, `x`, `menu`, `user`, `plus`, `minus`, `maximize`, `arrow-left-right`, `book-open`, `log-out`.
- [X] T008 [P] Create `script/generate_brand_assets.rb` and run it. It derives every brand asset from `app/assets/images/*.png` with the `vips` CLI (R16, R17).
  - **Wordmarks**, from `logo_with_text.png` trimmed to content:
    - `app/assets/images/brand/wordmark-64.webp` and `.png` (64 px tall);
    - `wordmark-160.webp` and `.png` (160 px tall).
  - **Favicon set**, from `logo_without_text.png` trimmed and transparent:
    - `public/favicon.ico` (16 and 32);
    - `public/icon.png` (512);
    - `public/icon-192.png`.
  - **Home-screen icons**, from `logo_without_text_with_bg.png`:
    - `public/apple-touch-icon.png` (180, opaque);
    - `public/icon-maskable.png` (512, mark inside the 80% safe zone).
  - **Link-preview image**: `public/og-image.png` (1200×630), from `logo_with_text_with_bg.png` padded with its own corner-pixel background colour.
  - Print that background colour as hex, for the manifest.
  - Delete `public/icon.svg` (the default red circle).
  - Commit the outputs.
- [X] T009 [P] Extend `script/generate_spec_fixtures.rb` to write `spec/fixtures/files/reader/`, then run it (R14). Stdlib plus the `zip` CLI. PNGs through `Zlib`.
  - `text-6-pages.pdf`: each page draws "Page N" in large text.
  - `reflowable-3-chapters.epub`: valid EPUB 3, `mimetype` stored first, nav document, spine of 3 chapters of about 1,500 words each, chapter titles "Chapter One/Two/Three".
  - `comic-4-pages.cbz`: `001.png`–`004.png`, 600×900, distinct solid colours.
  - `manga-rtl-4-pages.cbz`: same layout, different colours.
- [X] T010 [P] Create `script/generate_large_pdf.rb PATH` (SC-005).
  - It writes a ~500 MB PDF of 400 pages, each embedding an uncompressible random-noise image stream.
  - Usage comment at the top. Output goes to `tmp/` and is never committed.
- [X] T011 [P] Extend `spec/support/system_viewports.rb` (R11, R14).
  - `:mobile` registers and uses a `:headless_chrome_mobile` Selenium driver with Chrome `mobileEmulation` (`deviceMetrics: { width: 390, height: 844, pixelRatio: 3, touch: true }`, a mobile user agent).
  - `:desktop` stays 1440×900.
  - Do **not** run any generator that rewrites `spec/rails_helper.rb` or `spec/spec_helper.rb`. If one must run, back both up first.
- [X] T012 [P] Create `spec/support/reader_helpers.rb` (system specs only) with:
  - `wait_for_reader(state: "ready")`, which waits on `#reader[data-reader-state]`;
  - `reader_location` and `reader_progress`, which read the `data-reader-*` attributes;
  - `turn_page(:next | :prev, via: :key | :tap | :swipe)`;
  - `touch_swipe(from:, to:)`, using a Selenium touch pointer action;
  - `go_offline` and `go_online`, through `page.driver.browser.network_conditions`;
  - `emulate_reduced_motion`, through CDP `Emulation.setEmulatedMedia` with `prefers-reduced-motion: reduce`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Routes, reading-settings data, the shared design system, the layout, the
modal and the shared partials every story renders.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T013 Write the route map from contracts/http.md §Routes into `config/routes.rb`.
  - Add everything except `resource :preview_image`, which US9 adds.
  - Keep `get "up"`.
  - Enable `get "manifest" => "rails/pwa#manifest", as: :pwa_manifest`.
  - Run `bin/rails routes` to confirm the helpers exist: `book_reader_path`, `book_file_path`, `book_reading_position_path`, `recent_books_path`, `new_registration_path`, `edit_reading_settings_path` and the others.
- [X] T014 [P] Create the migration `db/migrate/<timestamp>_add_reading_settings_to_users.rb` from data-model.md, then run `bin/rails db:migrate` and commit `db/schema.rb`.
  - `reader_page_animation`: boolean, `null: false`, `default: true`.
  - `reader_theme`: string, `null: false`, `default: "light"`, with check constraint `users_reader_theme_check`: `reader_theme IN ('light', 'sepia', 'dark')`.
  - `reader_text_size`: integer, `null: false`, `default: 100`, with check constraint `users_reader_text_size_check`: `reader_text_size IN (80, 90, 100, 115, 130, 150, 175)`.
- [X] T015 [P] Write `spec/models/user/reading_settings_spec.rb`:
  - the defaults are `true`, `"light"` and `100`;
  - `reader_theme` accepts only light, sepia or dark (as a validation error, not an `ArgumentError`);
  - `reader_text_size` accepts only `TEXT_SIZES`;
  - `#reading_settings` returns `{ page_animation:, theme:, text_size: }`;
  - `#update_reading_settings` ignores keys other than the three, and returns `false` with errors on invalid input;
  - a successful update changes `cache_key_with_version`.
- [X] T016 Implement `app/models/user/reading_settings.rb` and `include ReadingSettings` in `app/models/user.rb` (depends on T014, T015).
  - `TEXT_SIZES = [80, 90, 100, 115, 130, 150, 175]`.
  - `enum :reader_theme, { light: "light", sepia: "sepia", dark: "dark" }, prefix: true, validate: true`.
  - `validates :reader_text_size, inclusion: { in: TEXT_SIZES }`.
  - `validates :reader_page_animation, inclusion: { in: [true, false] }`.
  - `#reading_settings` and `#update_reading_settings(attrs)`.
- [X] T017 [P] Add examples to `spec/models/book_spec.rb`:
  - `:card` and `:large` named cover variants exist;
  - `Book.find_visible_cached!` returns published books and the reader's archived library books;
  - it raises `ActiveRecord::RecordNotFound` for drafts and unknown ids;
  - `:caching`: a repeat call runs at most 1 query (`catalog_version`);
  - updating the book, or adding an archived book to the user's library, changes the result.
- [X] T018 Implement in `app/models/book.rb` (depends on T017):
  - `has_one_attached :cover` named variants:
    - `:card`: `resize_to_fill: [240, 360], format: :webp, preprocessed: true`;
    - `:large`: `resize_to_limit: [600, 900], format: :webp, preprocessed: true`.
  - `Book.find_visible_cached!(public_id, user:)`, cached under `["book/visible", Book.catalog_version, public_id, user.cache_key_with_version]`.
    - Preloads the cover, the file blob, the categories and the rich-text description.
    - Raises `RecordNotFound` like `find_visible!`.
- [X] T019 [P] Create `app/controllers/concerns/book_scoped.rb` and `app/views/books/not_available.html.erb` (FR-019).
  - The concern's `included` block adds `before_action :set_book` and `rescue_from ActiveRecord::RecordNotFound, with: :render_not_available`.
  - `set_book` sets `@book = Book.find_visible_cached!(params[:book_id] || params[:id], user: Current.user)`.
  - `render_not_available`: HTML gets the "This book isn't available" page with a home link, status 404; other formats get `head :not_found`.
  - Controllers that don't need `@book` on every action use `skip_before_action :set_book, only: …`.
- [X] T020 [P] Create `app/assets/stylesheets/shared/tokens.css`: every `DESIGN.md` token as a CSS custom property, with values verbatim from `DESIGN.md`.
  - Colours: canvas `#0a0d3a`, surface-indigo `#1e2353`, surface-onyx `#23272a`, surface-black `#000000`, primary `#5865f2`, green `#35ed7e`, magenta `#ec48bd`, link `#00b0f4`, ink `#ffffff`, ink-dark `#000000`, muted `#333333`.
  - Spacing: xxs 4 to section 40.
  - Radii: xs 6 to full 9999.
  - Type scale: display-xl to link-sm.
  - Elevation: `0 3px 68px rgba(69,42,124,0.1)`.
  - Breakpoints, as comments.
- [X] T021 [P] Create `app/assets/stylesheets/shared/fonts.css` and `shared/base.css`.
  - `fonts.css`: `@font-face` for the T006 files, with `font-display: swap`.
  - `base.css`:
    - body on the canvas colour;
    - the animated Blurple-to-magenta mesh on `body:not(.reader)::before`, static under `prefers-reduced-motion`;
    - Hanken Grotesk 800 uppercase for `.display` headings and Inter for body;
    - focus-visible ring and `.visually-hidden`;
    - a minimum 44 px target for interactive elements;
    - a centered 1200 px `.container` with a 16 px gutter on mobile.
- [X] T022 [P] Create `app/assets/stylesheets/shared/buttons.css`, `shared/cards.css` and `shared/forms.css`, per DESIGN.md components.
  - Buttons: `button-primary`, `button-green`, `button-white`, `button-ghost`, `button-ghost-sm`, `icon-button`.
  - Cards: a book card with a 2:3 cover at `rounded.lg` and a two-line title clamp; `feature-card-dark`; `empty-state`.
  - Forms: inputs on surface-indigo at `rounded.lg`, labels, inline error text, an error summary.
- [X] T023 [P] Create `app/assets/stylesheets/shared/nav.css` and `shared/modal.css`.
  - Nav: wordmark left, account menu right, collapsing to wordmark plus a menu button below 768 px.
  - Modal: `<dialog>` styled as `ex-modal-card` with the soft-float shadow and a backdrop.
- [X] T024 Rework `app/views/layouts/application.html.erb` and create the partials it renders: `app/views/shared/_nav.html.erb`, `_flash.html.erb` (`id="flash"`, a notice/alert toast region with `role="status"`) and `_modal.html.erb` (depends on T008, T020–T023).
  - Explicit `stylesheet_link_tag` for each `shared/*.css` plus `actiontext`, instead of `:app`, followed by `yield :stylesheets`.
  - Render `shared/_nav`:
    - the `brand/wordmark-64` image at 32 px CSS height, linking to `home_path`, with alt "Dev Library";
    - an account menu with the person's name and a Sign out button (`button_to session_path, method: :delete`).
  - Render `shared/_flash`, then `<main id="main" class="container">`, then `shared/_modal` (`<dialog data-controller="modal">` wrapping `turbo_frame_tag "modal"`).
- [X] T025 [P] Create two Stimulus controllers in `app/javascript/controllers/`: `modal_controller.js` and `menu_controller.js`.
  - `app/javascript/controllers/modal_controller.js` (R9):
    - `showModal()` on `turbo:frame-load`;
    - close on `turbo:submit-end` when `detail.success`;
    - on close, empty the frame and remove its `src`;
    - close and clear on `turbo:before-cache`;
    - Escape closes.
  - `app/javascript/controllers/menu_controller.js`: toggles the account menu, `aria-expanded`, closes on outside click or Escape.
- [X] T026 [P] Create `app/helpers/icons_helper.rb` and `app/helpers/covers_helper.rb`, with `spec/helpers/covers_helper_spec.rb` (R13).
  - `app/helpers/icons_helper.rb`: `icon(name, title: nil, **attrs)` inlines `app/assets/images/icons/#{name}.svg`. It is `aria-hidden` unless `title` is given, and raises on unknown names.
  - `app/helpers/covers_helper.rb`: `cover_image_tag(book, variant: :card)`.
    - Builds the representation URL with `signed_id(expires_at:)` rounded to the end of the next full hour, so the URL is stable within the hour.
    - Sets `width`/`height` from the variant, `loading: "lazy"`, `decoding: "async"` and `alt: book.title`.
    - Renders `shared/_cover_placeholder` when there is no cover.
  - `spec/helpers/covers_helper_spec.rb`: the same URL twice within one hour, a different URL in the next window, and the placeholder without a cover.
  - If rounded `expires_at` turns out not to be supported, implement the R13 fallback (a session-authorized `Books::CoversController`) and update data-model.md.
- [X] T027 [P] Create the shared partials in `app/views/shared/`.
  - `_book_card.html.erb`:
    - root `id="<%= dom_id(book) %>"`;
    - the cover links to `book_path(book)`;
    - the title has a two-line clamp and a `title` attribute;
    - a compact `button-ghost-sm` "Read" links to `book_reader_path(book)` (FR-005).
  - `_cover_placeholder.html.erb`: the title on a gradient tile.
  - `_see_more.html.erb`, taking `id:` and `url:`:
    - renders a `<div id>` with a "See more" link carrying `data: { turbo_stream: true }`, and never `turbo_action: "advance"`;
    - renders an empty `<div id>` when `url` is nil.
  - `_empty_state.html.erb`, taking a message and an optional link.

**Checkpoint**: Foundation ready. User stories can now be built.

---

## Phase 3: User Story 1 - Browse the newest books (Priority: P1) 🎯 MVP

**Goal**: Home lists published books newest first, 50 at a time. "See more" appends 50
more until the end, with no repeats or gaps (FR-003–FR-005).

**Independent Test**: Seed 120 published books, open home, tap "See more" twice: 50 → 100
→ 120, then "See more" is gone. Publishing a book between loads repeats and skips nothing.

### Tests for User Story 1 ⚠️ (write first, see them fail)

- [X] T028 [P] [US1] Write `spec/models/book/recent_spec.rb`:
  - order is `published_at` descending, then `id` descending;
  - returns 50 plus a `next_params` cursor when more exist, and `next_params: nil` on the last batch;
  - drafts and archived books are excluded;
  - a malformed or tampered cursor gives the first batch;
  - publishing a new book between batch 1 and batch 2 causes no repeat and no skip;
  - `:caching`: a repeat read runs only the `catalog_version` query, and publishing a book changes the result.
- [X] T029 [P] [US1] Update `spec/requests/home_spec.rb`:
  - replace "shows the blank home page" with: 50 cards newest first, each `id="book_<id>"`;
  - a "See more" link to `recent_books_path(before: …)` when more than 50 exist, and none at exactly 50;
  - the empty-state message with 0 published books;
  - keep the existing anonymous-redirect and lands-on-home examples.
- [X] T030 [P] [US1] Write `spec/requests/recent_books_spec.rb`:
  - the turbo_stream response appends 50 cards to `recent_books` and replaces `recent_books_more`, which is empty on the last batch;
  - a bad cursor gives the first batch;
  - the HTML fallback returns 200;
  - anonymous gets a 302 to sign-in.
- [X] T031 [P] [US1] Write `spec/system/home_spec.rb` inside `on_each_viewport`:
  - with 120 books: 50 visible, then "See more" → 100 → 120, and "See more" disappears;
  - publish a book between clicks: no duplicate `book_` ids on the page;
  - 0 books: the empty message.

### Implementation for User Story 1

- [X] T032 [P] [US1] Create `app/models/book/page.rb`: `Book::Page = Data.define(:books, :next_params)`.
- [X] T033 [US1] Create `app/models/book/recent.rb` and add `Book.recent(before: nil, per: 50)` to `app/models/book.rb` (data-model "Book::Recent", R3).
  - Keyset on `(published_at, id) < (cursor)`, fetching `per + 1`.
  - The cursor is a URL-safe Base64 of `"#{published_at.to_fs(:usec)}|#{id}"`; parse it defensively.
  - Covers preloaded.
  - Returns `Book::Page`.
  - Cached under `["catalog/recent", Book.catalog_version, cursor, per]`.
- [X] T034 [US1] Implement `HomeController#show` (`@recent = Book.recent`) and `app/views/home/show.html.erb`.
  - A `content_for :stylesheets` link to `pages/home`.
  - Placeholder comments for the US6 search box and the US2 collection row.
  - The "NEWEST BOOKS" `.display` heading.
  - `<div id="recent_books" class="book-grid">` rendering `shared/book_card` for each book.
  - `shared/see_more` with `id: "recent_books_more"` and `url: recent_books_path(@recent.next_params)` (or nil).
  - The empty state when there are no books.
- [X] T035 [US1] Implement `app/controllers/recent_books_controller.rb#index` (`Book.recent(before: params[:before])`).
  - `app/views/recent_books/index.turbo_stream.erb`: `turbo_stream.append "recent_books"` with the cards, and `turbo_stream.replace "recent_books_more"`.
  - `app/views/recent_books/index.html.erb`: the plain fallback.
- [X] T036 [US1] Create `app/assets/stylesheets/pages/home.css`.
  - `.book-grid`: `repeat(auto-fill, minmax(120px, 1fr))` on mobile and `minmax(160px, 1fr)` from 768 px, with a `spacing.md` gap.
  - Section spacing per DESIGN.md.
- [X] T037 [US1] Add 120 published seed books to `db/seeds.rb`.
  - Titles "Seed Book 001"–"Seed Book 120", with `published_at` one hour apart.
  - Every third one gets `cover.png`, and all use `sample.pdf`.
  - Idempotent through `find_or_create_by!(title:)`. Keep the existing three books.
- [X] T038 [US1] Live-verify with Playwright MCP (quickstart §4 step 3), mobile first, then desktop. Save screenshots to `.playwright-mcp/us1-mobile.png` and `.playwright-mcp/us1-desktop.png`.

**Checkpoint**: The home page lists and pages the newest books. MVP increment.

---

## Phase 4: User Story 2 - Your collection first (Priority: P1)

**Goal**: A "Your collection" row above the newest books, ordered by last read, scrolling
sideways, opening the reader directly (FR-006–FR-008).

**Independent Test**: Account A has 3 library books with positions, account B has none.
A sees the row in last-read order, and B sees no row.

### Tests for User Story 2 ⚠️

- [X] T039 [P] [US2] Write `spec/requests/home_collection_spec.rb`:
  - `#collection` renders only when the library has entries;
  - items are ordered by last read, then date added;
  - each links to `book_reader_path`;
  - the reading percentage is shown;
  - an archived book in the library still appears;
  - another account's library never shows.
- [X] T040 [P] [US2] Write `spec/system/home_collection_spec.rb` inside `on_each_viewport`:
  - the row appears above "NEWEST BOOKS";
  - mobile: `touch_swipe` across the row moves `scrollLeft` and leaves `window.scrollY` unchanged;
  - desktop: the next and previous buttons scroll it;
  - clicking an item navigates to `/books/:id/read`.

### Implementation for User Story 2

- [X] T041 [US2] Create `app/views/home/_collection.html.erb` and render it in `app/views/home/show.html.erb` only when `Current.user.library.search` returns entries.
  - The "YOUR COLLECTION" heading.
  - A `<div id="collection" data-controller="scroll-row">` with previous and next icon buttons.
  - Each entry shows `cover_image_tag`, the title below, and a progress bar (`role="progressbar"`, `aria-valuenow` = `reading_progress`).
  - Each entry is wrapped in a link to `book_reader_path(entry.book)`.
- [X] T042 [P] [US2] Create `app/javascript/controllers/scroll_row_controller.js`.
  - Previous and next buttons scroll by the visible width with `behavior: "smooth"` (instant under reduced motion), and hide at either end.
  - Arrow keys work when the row has focus.
  - Buttons are hidden on `(pointer: coarse)`.
- [X] T043 [US2] Add collection-row styles to `app/assets/stylesheets/pages/home.css`.
  - `overflow-x: auto`, `scroll-snap-type: x mandatory`, `overscroll-behavior-x: contain`, with the scrollbar hidden on touch.
  - Items are 120 px wide on mobile and 160 px on desktop.
  - A thin progress bar in Blurple.
- [X] T044 [US2] Give `reader@devlibrary.test` 3 library books with positions at different `read_at` times in `db/seeds.rb`.
  - The Sample PDF at page "3".
  - Café Noir at progress 40.
  - The manga at page "2".
- [X] T045 [US2] Live-verify quickstart §4 steps 1–2 (and step 9 for the empty account), mobile then desktop. Screenshots go to `.playwright-mcp/us2-*.png`.

**Checkpoint**: Home shows the person's collection first.

---

## Phase 5: User Story 3 - Read and resume exactly where you stopped (Priority: P1)

**Goal**: One-tap reader for PDF, EPUB and CBZ. It opens at the account's saved position,
saves every turn through the outbox, follows the reading direction, and supports theme,
text size and zoom. CBR shows the "can't be opened yet" state (FR-021–FR-030, FR-033).

**Independent Test**: For each reader fixture: open it, turn 3 pages, reopen it in a fresh
session, and land on the same position. Navigate away, go offline, or expire the session
right after a turn, and the position is still saved.

### Tests for User Story 3 ⚠️

- [X] T046 [P] [US3] Write `spec/requests/books/readers_spec.rb`:
  - the shell has every `data-reader-*` value from reader-client.md §1;
  - the start location and progress come from `ReadingPosition.for`;
  - the effective direction honours the per-user override;
  - a CBR book renders `data-reader-state="unsupported"`;
  - a book without a file renders `error`;
  - a draft gives 404 and anonymous gives 302.
- [X] T047 [P] [US3] Write `spec/requests/books/files_spec.rb`:
  - a full GET returns 200 with `Accept-Ranges: bytes`, `Content-Length`, `Cache-Control: private, no-store` and no `Content-Encoding`;
  - `Range: bytes=0-99` returns 206 with `Content-Range` and 100 bytes;
  - an unsatisfiable range returns 416;
  - a draft gives 404 and anonymous gives 302;
  - an archived book still in the reader's library returns 200.
- [X] T048 [P] [US3] Write `spec/requests/books/reading_positions_spec.rb`:
  - a JSON PATCH returns 204 and stores the position;
  - a PATCH carrying an older `read_at` after a newer one keeps the newer one;
  - anonymous JSON returns **401**, not a redirect;
  - a draft gives 404;
  - progress 150 gives 422 with `{ errors: [...] }`.
- [X] T049 [P] [US3] Write `spec/requests/books/reading_directions_spec.rb`:
  - a PATCH with `direction: "ltr"` on a manga stores the override and its turbo_stream replaces `reader_preferences`;
  - a blank `direction` clears the override;
  - `direction: "up"` gives 422;
  - anonymous gives 302.
- [X] T050 [P] [US3] Write `spec/requests/reading_settings_spec.rb` (theme and text size):
  - a PATCH with `reader_theme: "dark"` and `reader_text_size: 130` persists, and the turbo_stream replaces `reading_settings_form` and, with `book_id`, `reader_preferences`;
  - an invalid theme gives 422;
  - anonymous gives 302;
  - an extra `user_id` param is ignored.
- [X] T051 [P] [US3] Write `spec/system/reader_spec.rb` inside `on_each_viewport`. For the PDF, EPUB, comic and RTL-manga fixtures:
  - open from the book card "Read" → `wait_for_reader` → turn 3 pages → the location changes;
  - sign out, sign in again, reopen → the same `reader_location`.

  Also covered:
  - manga: tapping the left edge, and ArrowLeft, go forward;
  - switch the direction to LTR, reload, and the choice is kept;
  - EPUB: text size up and the dark theme keep the same CFI chapter label;
  - comic on mobile: pinch zoom pauses turns, and Fit resumes them;
  - the last page gives `next` → the end indicator;
  - CBR shows the unsupported message with a back link.
- [X] T052 [P] [US3] Write `spec/system/reader_persistence_spec.rb` inside `on_each_viewport`. Each case then reopens the book and checks the page:
  - turn a page, then immediately `visit home_path`;
  - `go_offline`, turn 2 pages, `go_online`;
  - turn a page, delete the session row, turn again, see the sign-in banner, sign in, and return.

### Implementation for User Story 3

- [X] T053 [US3] In `app/controllers/concerns/authentication.rb`, make `request_authentication` answer `head :unauthorized` when `request.format.json?`. Keep the HTML redirect unchanged (R5).
- [X] T054 [P] [US3] Create `app/controllers/books/files_controller.rb` (R6).
  - `include BookScoped` and `ActiveStorage::Streaming`.
  - A single `Range` → `send_blob_byte_range_data`. Otherwise → `send_blob_stream`.
  - Always set `Accept-Ranges: bytes` and `Cache-Control: private, no-store`.
  - 404 without a file.
- [X] T055 [P] [US3] Create `app/controllers/books/reading_positions_controller.rb#update`.
  - JSON only. `include BookScoped`.
  - Permit only `location`, `progress` and `read_at`.
  - `ReadingPosition.record!(user: Current.user, book: @book, …)` → `head :no_content`.
  - `RecordInvalid` → 422 with `{ errors: }`.
- [X] T056 [P] [US3] Create `app/controllers/books/reading_directions_controller.rb#update`.
  - `ReadingPosition.set_direction!(user: Current.user, book: @book, direction: params[:direction].presence)`.
  - Responds with `app/views/books/reading_directions/update.turbo_stream.erb`, which replaces `reader_preferences`.
  - 422 on an invalid value.
- [X] T057 [P] [US3] Create `app/javascript/controllers/auto_submit_controller.js`: `requestSubmit()` on `change`, debounced 150 ms for text inputs.
- [X] T058 [US3] Create `app/controllers/reading_settings_controller.rb` (`edit` and `update`, always on `Current.user`, permitting `reader_theme` and `reader_text_size`).
  - Views in `app/views/reading_settings/`:
    - `_form.html.erb`, `id="reading_settings_form"`, with `data-controller="auto-submit"`, a theme radio group (Light, Sepia, Dark), a 7-step text-size control, and a hidden `book_id` when it is in the reader;
    - `edit.html.erb`, which wraps the form in `turbo_frame_tag "modal"`;
    - `update.turbo_stream.erb`, which replaces `reading_settings_form` (with a "Saved" status) and replaces `reader_preferences` when `book_id` resolves through `Book.find_visible_cached!`.
- [X] T059 [US3] Create `app/controllers/books/readers_controller.rb#show` (`include BookScoped`, `layout "reader"`) and its views.
  - `app/views/layouts/reader.html.erb`:
    - `viewport-fit=cover`, `class="reader"` on body, no nav, no logo, no mesh;
    - shared `tokens`, `fonts` and `base` CSS plus `shared/reader_themes` and `pages/reader`.
  - `app/views/books/readers/show.html.erb`: the shell exactly as reader-client.md §1, filled from `ReadingPosition.for`, `Current.user.reading_settings` and `effective_reading_direction`.
  - `_preferences.html.erb`: the `id="reader_preferences"` element.
  - `_toolbar.html.erb`: back, title, progress label, the "Aa" settings toggle, and the direction switch form (PATCH `book_reading_direction_path`).
  - `_settings_panel.html.erb`: renders `reading_settings/_form` with `book_id`.
  - State blocks for `loading`, `error`, `unsupported` (CBR, server-rendered), `unavailable` and `blocked`.
- [X] T060 [P] [US3] Create the reader stylesheets `app/assets/stylesheets/shared/reader_themes.css` and `app/assets/stylesheets/pages/reader.css`.
  - `app/assets/stylesheets/shared/reader_themes.css`, the light, sepia and dark surface tokens:
    - `--reader-bg`/`--reader-fg` = `#ffffff`/`#1a1a1a`, `#f4ecd8`/`#5b4636` and `#121212`/`#e0e0e0`;
    - plus link colours.
  - `app/assets/stylesheets/pages/reader.css`:
    - full-viewport surface with safe-area insets;
    - invisible 30% tap zones;
    - auto-hiding toolbar;
    - 44 px controls, zoom controls, the end-of-book indicator and the state overlays.
- [X] T061 [P] [US3] Create `app/javascript/reader/outbox.js` exactly per reader-client.md §6.
  - The localStorage key format, wrapped in `try/catch`.
  - One request in flight, coalescing.
  - `fetch` PATCH with `keepalive`, JSON, and the CSRF header.
  - Backoff 1 s doubling to 30 s.
  - Responses: 204 clear, 401 banner plus pause, 403 → `blocked` state, 404 drop plus `unavailable`, 422 drop.
  - Flush triggers: `visibilitychange`, `pagehide`, `online`, and an explicit `flush()` for `disconnect()`.
- [X] T062 [P] [US3] Create `app/javascript/reader/input.js` per reader-client.md §5.
  - Tap zones: outer 30%, middle toggles the toolbar.
  - Swipe: at least 40 px, within 30° of horizontal.
  - Arrow keys are visual and Page/Space keys are logical, mapped through the direction.
  - Ignored while zoomed.
  - `attach(doc)` for iframe documents.
  - Emits `next`, `prev` and `toggle-chrome`.
- [X] T063 [P] [US3] Create `app/javascript/reader/sources/pdf_source.js`.
  - `import * as pdfjs from "pdfjs-dist"`, with `GlobalWorkerOptions.workerSrc = import.meta.resolve("pdfjs-dist/worker")`.
  - `getDocument({ url, disableStream: true, disableAutoFetch: true, cMapUrl, standardFontDataUrl, wasmUrl, iccUrl })`, the folders under `/vendor/pdfjs-dist/6.4.299/`.
  - `pageCount`, `pageSize(i)` and `render(i, { width, height, scale })` → a `<canvas>`, the scale capped at 2× and 16 MP.
- [X] T064 [P] [US3] Create `app/javascript/reader/sources/cbz_source.js`.
  - `configure({ useWebWorkers: false })`, then `new ZipReader(new HttpRangeReader(fileUrl))`.
  - Image entries, natural-sorted by filename.
  - `render(i)` → an `<img>` with an object URL, revoked on destroy.
  - `pageSize(i)` from the decoded image.
- [X] T065 [US3] Create `app/javascript/reader/engines/fixed_layout.js` (depends on T063, T064).
  - Implements the reader-client.md §2 adapter for a source.
  - A 3-slot track (previous, current, next pre-rendered) ordered by direction.
  - `next`/`prev` return `false` at the ends. `goTo` clamps to `1..pageCount`.
  - `relocate` detail per §3, with the label "Page N of M".
  - Zoom: pinch, double-tap 2×, Ctrl/⌘ + wheel, `in`/`out`/`fit` and `isZoomed`.
  - `setDirection`, and `setTheme` for the surround only.
  - `setAnimation` is a no-op that stores the flag; US4 adds the slide.
  - `destroy`.
- [X] T066 [US3] Create `app/javascript/reader/engines/reflowable.js`, the foliate-js adapter.
  - `await import("foliate-js/view")`, then create `<foliate-view>` and `view.open(fileUrl)`.
  - `view.init({ lastLocation: startLocation })`. If that fails → `goToFraction(startProgress / 100)`. Nothing saved → start.
  - `relocate` → `{ location: cfi, progress: fraction * 100, label: tocItem?.label }`.
  - `setDirection` through the book direction and `goLeft`/`goRight`.
  - `setTheme`/`setTextSize` through `renderer.setStyles()`, using the reader_themes values.
  - Attaches `input.js` to each section's `doc` on the `load` event.
  - `setAnimation` stores the flag; US4 wires it. `destroy`.
- [X] T067 [US3] Create `app/javascript/controllers/reader_controller.js` and `app/javascript/controllers/reader_preferences_controller.js` (depends on T061–T066).
  - `app/javascript/controllers/reader_controller.js`:
    - picks the start position (server values, or a newer outbox entry);
    - `import()`s the adapter by format;
    - wires input to `next`/`prev`;
    - on `relocate`: `outbox.record()` and sets `data-reader-location`, `data-reader-progress` and `data-reader-state`;
    - applies `reader-preferences:changed`;
    - `outbox.flush()` and `adapter.destroy()` on `disconnect()`.
  - `app/javascript/controllers/reader_preferences_controller.js`: dispatches `reader-preferences:changed` with its values on `connect()`.
- [X] T068 [US3] Add the four reader fixtures as published seed books with covers in `db/seeds.rb`.
  - "Reader Test PDF", "Reader Test EPUB", "Reader Test Comic", and "Reader Test Manga" with `kind: "manga"`.
- [ ] T069 [US3] Live-verify quickstart §4 steps 6–7, mobile then desktop, for every fixture. Screenshots go to `.playwright-mcp/us3-*.png`.

**Checkpoint**: All three P1 stories work. Home, collection and reader make the first
releasable slice.

---

## Phase 6: User Story 4 - Page-turn animation the person can switch off (Priority: P2)

**Goal**: A 250 ms slide in the reading direction by default. It can be switched off per
account (instant), is always instant under reduced motion, and is interruptible
(FR-031, FR-032, FR-034, FR-035).

**Independent Test**: Turn pages with the setting on and off in two sessions of the same
account. Off is instant everywhere. RTL mirrors. Three quick taps land three pages ahead.

### Tests for User Story 4 ⚠️

- [X] T070 [P] [US4] Add to `spec/requests/reading_settings_spec.rb`:
  - PATCH `reader_page_animation: "0"` and `"1"` persist;
  - `edit` renders inside `turbo-frame#modal`;
  - the turbo_stream carries the new `animation` value in `reader_preferences`.
- [X] T071 [P] [US4] Write `spec/system/page_animation_spec.rb` inside `on_each_viewport`:
  - a new account → `data-reader-animation="slide"`, and `data-reader-turning` appears during a turn;
  - switch it off in the reader panel → `none`, the location changes within 100 ms of the key press, and a second session is also `none`;
  - an RTL manga sets the slide direction attribute to mirrored;
  - 3 quick ArrowRight presses → the location advances by exactly 3;
  - `emulate_reduced_motion` → `none` with the setting on;
  - Reading settings from the account menu opens the modal and toggles it.

### Implementation for User Story 4

- [X] T072 [US4] Implement the slide in `app/javascript/reader/engines/fixed_layout.js` (R4).
  - A Web Animations `translateX` of the track, 250 ms `ease-out`.
  - Forward moves left in LTR and right in RTL.
  - New input calls `finish()` on the running animation before the next move.
  - A swipe follows the finger and settles with the same curve.
  - Toggles `data-reader-turning` through a callback.
  - Nothing is animated when `setAnimation(false)`.
- [X] T073 [US4] In `app/javascript/reader/engines/reflowable.js`, make `setAnimation(on)` add or remove the `animated` attribute on foliate's renderer.
- [X] T074 [US4] In `app/javascript/controllers/reader_controller.js`, compute `effective = preferences.animation && !matchMedia("(prefers-reduced-motion: reduce)").matches`.
  - Re-evaluate it on media change and on preference change.
  - Write `data-reader-animation` (`slide` or `none`) and call `adapter.setAnimation(effective)`.
- [X] T075 [US4] Add the animation setting to `app/views/reading_settings/_form.html.erb`, `app/controllers/reading_settings_controller.rb` and `app/views/books/readers/_preferences.html.erb`.
  - `app/views/reading_settings/_form.html.erb`: a `role="switch"` checkbox labelled "Animate page turns", with the hint "Pages change instantly when off".
  - Permit `reader_page_animation` in `app/controllers/reading_settings_controller.rb`.
  - Render its value in `app/views/books/readers/_preferences.html.erb`.
- [X] T076 [US4] Add a "Reading settings" item to the account menu in `app/views/shared/_nav.html.erb`.
  - It links to `edit_reading_settings_path` with `data: { turbo_frame: "modal" }`.
  - Add a "Done" button that closes the dialog to `app/views/reading_settings/edit.html.erb`.
- [ ] T077 [US4] Live-verify quickstart §4 step 8, mobile then desktop. Screenshots go to `.playwright-mcp/us4-*.png`.

**Checkpoint**: Page turns animate, and the setting follows the account.

---

## Phase 7: User Story 5 - Book page with ratings and reviews (Priority: P2)

**Goal**: The book page with cover, title, authors, categories, description, Read CTA,
rating summary and paged reviews. An inline review form with stars, Trix and an emoji
picker. Edit in the modal, delete for the author or an admin (FR-013–FR-019).

**Independent Test**: Open a published book with reviews. Post 4★ "Loved it 🤩", which
prepends and updates the average without a reload. Edit it to 2★ in the modal, then
delete it.

### Tests for User Story 5 ⚠️

- [ ] T078 [P] [US5] Add to `spec/models/review_spec.rb`:
  - `Review.by(user, book:)` returns the person's review or `nil`;
  - `:caching`: a repeat call runs no SQL, and updating the review changes the result (key `["book", book.cache_key_with_version, "review_by", user.id]`).
- [ ] T079 [P] [US5] Write `spec/requests/books_spec.rb` for `GET /books/:id` signed in:
  - shows the cover, title, authors, category names, the description with emoji, "Start reading" or "Continue reading (N%)", `#rating_summary`, `#review_form`, and 20 reviews plus `#reviews_more`;
  - an archived book in the library shows reviews and no form;
  - a draft gives 404 "This book isn't available".
- [ ] T080 [P] [US5] Write `spec/requests/books/reviews_spec.rb`:
  - `index` page 2 as turbo_stream appends to `reviews` and replaces `reviews_more`;
  - `create`:
    - success streams prepend `reviews`, replace `review_form` and replace `rating_summary`;
    - a missing rating or blank content gives 422 with the input kept;
    - a second review gives 422;
    - an unpublished book gives 422;
  - anonymous gives 302.
- [ ] T081 [P] [US5] Write `spec/requests/reviews_spec.rb`:
  - `edit` by the author renders inside the `modal` frame;
  - `edit` or `update` by another reader gives 404;
  - `update` streams replace `dom_id(review)`, `review_form` and `rating_summary`, and update `modal`;
  - an invalid update gives 422 inside the modal;
  - `destroy` by the author or by an admin removes it and updates the summary;
  - `destroy` by another reader gives 404;
  - anonymous gives 302.
- [ ] T082 [P] [US5] Write `spec/system/book_page_spec.rb` inside `on_each_viewport`:
  - the page content;
  - post a review using the stars, Trix and the emoji picker → it appears at the top, and the average and count update with no full reload (assert a `window` marker survives);
  - validation keeps the typed text;
  - edit in the modal, then delete;
  - an admin deletes another person's review;
  - an archived book has no form;
  - a draft URL shows "not available";
  - 45 reviews → 20, then "See more reviews" → 40 → 45.

### Implementation for User Story 5

- [ ] T083 [P] [US5] Add `Review.by(user, book:)` to `app/models/review.rb`, cached under `["book", book.cache_key_with_version, "review_by", user.id]`.
- [ ] T084 [P] [US5] Create `app/helpers/ratings_helper.rb` and `spec/helpers/ratings_helper_spec.rb`.
  - `stars(rating)`: filled and empty star icons with `aria-label` "4 out of 5 stars".
  - `rating_summary_text(book)`: "4.2 · 17 reviews", "No reviews yet", with correct singular and plural.
- [ ] T085 [US5] Implement `app/controllers/books_controller.rb#show` (`include BookScoped`, plus `skip_before_action :set_book, only: :index`) and its views.
  - It loads `@reviews = Review.for_book(@book, page: 1)`, `@own_review = Review.by(Current.user, book: @book)` and `@position = ReadingPosition.for(user: Current.user, book: @book)`.
  - `app/views/books/show.html.erb`, linking `pages/books` in `content_for :stylesheets`:
    - the `:large` cover;
    - the title as a `.display` heading, the authors, and category `badge`s;
    - the rich-text description;
    - the green `button-green` "Start reading" or "Continue reading (N%)" linking to `book_reader_path`;
    - an empty `<div id="library_controls">` slot for US7;
    - `#rating_summary`;
    - `#review_form`, or the own-review panel, or the "Reviews are closed for archived books" notice;
    - `#reviews` and `#reviews_more`.
  - `app/views/books/_rating_summary.html.erb`, with `id="rating_summary"`.
- [ ] T086 [US5] Create `app/controllers/books/reviews_controller.rb` (`index`, `create`) and the views in `app/views/books/reviews/`.
  - `_form.html.erb`, `id="review_form"`:
    - star radios 1–5 with `data-controller="star-input"`;
    - `form.rich_text_area :content` with an emoji button `data-controller="emoji-picker"`;
    - an error summary.
  - `_review.html.erb`, `id=dom_id(review)`:
    - author name, `stars`, content and `time_tag`;
    - an Edit link (`data-turbo-frame="modal"`) for the author;
    - a Delete `button_to` for the author or an admin.
  - `_own_review.html.erb` (`id="review_form"`, "Your review").
  - `index.turbo_stream.erb` and `create.turbo_stream.erb`.
  - On failure, render `create.turbo_stream.erb`'s error branch with `status: :unprocessable_content`.
- [ ] T087 [US5] Create `app/controllers/reviews_controller.rb` (`edit`, `update`, `destroy`) with the contracts/http.md authorization.
  - Edit and update: `Current.user.reviews.find`.
  - Destroy: admin → `Review.find`, otherwise `Current.user.reviews.find`.
  - Views in `app/views/reviews/`:
    - `edit.html.erb`, `turbo_frame_tag "modal"` with an inner `id="modal_body"`;
    - `update.turbo_stream.erb`, including `turbo_stream.update "modal"` with empty content;
    - `destroy.turbo_stream.erb`.
- [ ] T088 [P] [US5] Create `app/javascript/controllers/star_input_controller.js` and `app/assets/stylesheets/shared/stars.css` (linked in the application layout).
  - The radio group is rendered as stars, with arrow-key support and a hover preview on fine pointers.
  - Touch targets are at least 44 px.
- [ ] T089 [P] [US5] Create `app/javascript/controllers/emoji_picker_controller.js` (R8).
  - Lazy `import("emoji-picker-element")` on first open.
  - `data-source="/vendor/emoji-picker-element/1.29.1/data.json"`.
  - A popover anchored to the button.
  - Saves `editor.getSelectedRange()` on open, then `setSelectedRange` + `insertString(event.detail.unicode)`.
  - Closes on Escape or an outside click.
  - Picker styles in `shared/forms.css`.
- [ ] T090 [US5] Create `app/assets/stylesheets/pages/books.css` and restyle `app/assets/stylesheets/actiontext.css` with tokens.
  - Book page: cover beside the text on desktop, stacked on mobile; review list spacing.
  - Trix editor and toolbar on surface-indigo.
- [ ] T091 [US5] Add 45 reviews of "Café Noir" to `db/seeds.rb`, from 45 seeded reviewers (`reviewer01@devlibrary.test`–`reviewer45@devlibrary.test`) with ratings 1–5 and emoji in the content. Idempotent.
- [ ] T092 [US5] Live-verify quickstart §4 step 5, mobile then desktop. Screenshots go to `.playwright-mcp/us5-*.png`.

**Checkpoint**: The book page shows reviews and accepts them.

---

## Phase 8: User Story 6 - Search from the home page (Priority: P2)

**Goal**: A centered search box at the top of home. The results have category and sort
dropdowns and "See more" in batches of 50 (FR-002, FR-009–FR-012).

**Independent Test**: "cafe" finds "Café Noir". Category and sort keep the text. 80 matches
show as 50 + 30. No matches shows the message.

### Tests for User Story 6 ⚠️

- [ ] T093 [P] [US6] Write `spec/models/book/search_page_spec.rb`:
  - `Book.search_page` returns `Book::Page`;
  - `next_params` is `{ page: n + 1 }` when there are more, and `nil` on the last page;
  - it delegates the rules to `Book::Search`;
  - `:caching`: a hit, then a publish changes the result.
- [ ] T094 [P] [US6] Write `spec/requests/search_results_spec.rb`:
  - `GET /books?q=cafe` (HTML) shows the filled search box, the category select with "All categories", and the sort select;
  - page 2 as turbo_stream appends to `search_results` and replaces `search_results_more`;
  - an unknown category or sort is ignored;
  - no match shows "No books found" with a home link;
  - a blank `q` gives newest first;
  - anonymous gives 302.
- [ ] T095 [P] [US6] Write `spec/system/search_spec.rb` inside `on_each_viewport`:
  - the search box is centered at the top of home;
  - "cafe" finds "Café Noir";
  - choosing "Fantasy" keeps the text;
  - "Top rated" changes the order;
  - 80 matches show as 50 + 30;
  - the no-results message.

### Implementation for User Story 6

- [ ] T096 [US6] Add `Book.search_page(query:, category:, sort:, page:, per: 50)` to `app/models/book.rb`.
  - `per + 1` look-ahead over `Book::Search#scope`.
  - Cached under `["catalog/search_page", Book.catalog_version, normalized_q, category_id, sort, page, per]`.
  - Returns `Book::Page`.
- [ ] T097 [US6] Create `app/views/shared/_search_form.html.erb` and `app/assets/stylesheets/shared/search.css` (linked in the application layout), and render the form at the top of `app/views/home/show.html.erb`.
  - `role="search"`, centered and large.
  - A visually hidden label "Search books", the search icon, `GET books_path`, `name="q"` with its value preserved.
- [ ] T098 [US6] Implement `app/controllers/books_controller.rb#index` and its views.
  - `app/views/books/index.html.erb`:
    - the search form, plus a category select from `Category.cached_ordered` ("All categories");
    - a sort select (Relevance only when `q` is present, then Newest, Title A–Z, Title Z–A, Top rated), auto-submitting through `data-controller="auto-submit"`;
    - `#search_results` with book cards and `#search_results_more`;
    - the "No books found" empty state with a home link.
  - `app/views/books/index.turbo_stream.erb`.
- [ ] T099 [US6] Live-verify quickstart §4 step 4, mobile then desktop. Screenshots go to `.playwright-mcp/us6-*.png`.

**Checkpoint**: Search works from home.

---

## Phase 9: User Story 8 - Sign up, branding and account protection (Priority: P2)

**Goal**: Sign-up and a branded `auth` layout for sign-in and password pages. Favicon, app
and home-screen icons. DevCine/Spotsby-style protection: per-email throttle with a generic
response, blocked accounts, and a lock email (FR-039–FR-045, FR-050–FR-054).

**Independent Test**: Sign up "Ana" and land home. Check the logos on every auth page and
the tab icon. The 6th attempt for one email is refused generically. A blocked account
can't sign in and is kicked out mid-session.

### Tests for User Story 8 ⚠️

- [ ] T100 [P] [US8] Write `spec/models/user/blockable_spec.rb`:
  - `block!` sets `blocked_at`, destroys every session, and leaves `role` and the lockout columns unchanged;
  - `block!` is idempotent;
  - `unblock!` clears it;
  - a password change does not clear `blocked_at`.
- [ ] T101 [P] [US8] Add to `spec/models/user/lockable_spec.rb`:
  - `authenticate_with_lockout` returns `nil` for a blocked user with the correct password, without changing `failed_sign_in_attempts`;
  - reaching 5 failures enqueues exactly one `PasswordsMailer.locked`;
  - attempts during the lock enqueue nothing;
  - a blocked user never triggers it.
- [ ] T102 [P] [US8] Write `spec/mailers/passwords_mailer_spec.rb` for `locked(user)`:
  - subject "Your Dev Library account was locked: reset your password to unlock it";
  - sent to the user;
  - the body contains `edit_password_url(user.password_reset_token)`.
- [X] T103 [P] [US8] Write `spec/requests/registrations_spec.rb`:
  - `new` returns 200 with the `auth` layout wordmark;
  - signed in → `new` redirects to `/`;
  - `create` with name "Ana" and email " Ana@Example.COM " → a reader with `ana@example.com`, a session, and a redirect to `after_authentication_url`;
  - `user[role]=admin` still makes a reader;
  - a missing name gives 422 with the name and email kept and the password fields empty;
  - a duplicate email in another case gives 422;
  - a short or mismatched password gives 422;
  - the 11th create within 3 minutes from one IP redirects with "Try again later.".
- [ ] T104 [P] [US8] Update `spec/requests/sessions_spec.rb`:
  - the IP bucket (11th attempt) now returns the **generic** "Try another email address or password.";
  - the 6th attempt for one email within 15 minutes from 6 different `REMOTE_ADDR`s is refused even with the correct password;
  - a blocked account with the correct password gets the generic failure;
  - unknown, wrong, locked, blocked, IP-throttled and email-throttled responses are byte-identical (status, location, flash);
  - signed in → `GET /session/new` redirects to `/`.
- [ ] T105 [P] [US8] Write `spec/requests/blocked_session_spec.rb`. After `user.block!` on a signed-in user:
  - an HTML `GET /` → 302 `/session/new` with flash "Your account has been blocked.", and the session row is gone;
  - a JSON PATCH of the reading position → 403 and no position written;
  - an Active Storage blob URL → 302 sign-in.
- [X] T106 [P] [US8] Write `spec/system/sign_up_and_branding_spec.rb` inside `on_each_viewport`:
  - sign-in shows the wordmark image (alt "Dev Library") and a "Create an account" link;
  - sign up as Ana → home, signed in;
  - a missing name keeps the typed values;
  - the forgot-password and reset-password pages show the wordmark;
  - the header wordmark links home;
  - `link[rel=icon]` points to `/favicon.ico` and `/icon.png`;
  - signed in, visiting sign-in or sign-up lands on home.
- [ ] T107 [P] [US8] Write `spec/system/account_protection_spec.rb` inside `on_each_viewport`:
  - 5 attempts for one email, then the correct password → the generic message, still on sign-in;
  - a blocked account → the generic message;
  - signed in, then `block!` in the spec, then click a link → sign-in with "Your account has been blocked."

### Implementation for User Story 8

- [ ] T108 [US8] Create the migration `db/migrate/<timestamp>_add_blocked_at_to_users.rb`, then run the migration and commit `db/schema.rb`.
  - `blocked_at`: datetime, nullable.
  - A partial index `index_users_on_blocked_at` with `where: "blocked_at IS NOT NULL"`.
- [ ] T109 [US8] Create `app/models/user/blockable.rb` (`blocked?`, `block!` running `update!(blocked_at: Time.current)` plus `sessions.destroy_all` in one transaction, and `unblock!`). `include Blockable` in `app/models/user.rb` (depends on T108, T100).
- [ ] T110 [US8] Update `app/models/user/lockable.rb` (R18, depends on T109, T101).
  - `authenticate_with_lockout`: for a blocked user, call `authenticate` (result ignored) and return `nil` without counting.
  - `register_failed_sign_in!`: return early when blocked.
  - On the transition into a new lock, enqueue `PasswordsMailer.locked(self).deliver_later` after commit.
- [ ] T111 [P] [US8] Add `PasswordsMailer#locked(user)` to `app/mailers/passwords_mailer.rb`, with `app/views/passwords_mailer/locked.html.erb` and `locked.text.erb`.
  - The text explains the lock and that resetting the password unlocks the account.
  - It links to `edit_password_url(@user.password_reset_token)`.
- [ ] T112 [US8] Update `app/controllers/concerns/authentication.rb`.
  - `resume_session`: when the session's user is `blocked?`, destroy that session, delete the cookie, and mark the request as blocked.
  - `require_authentication`: for a blocked request, HTML gets `redirect_to new_session_path, alert: "Your account has been blocked."` and JSON gets `head :forbidden`.
  - Add `redirect_if_authenticated`, which redirects to `root_path` when `authenticated?`.
- [ ] T113 [US8] Update `app/controllers/sessions_controller.rb` (R18).
  - `layout "auth"`.
  - `before_action :redirect_if_authenticated, only: :new`.
  - Replace the single `rate_limit` with two:
    - `name: "ip"`: 10 per 3 minutes;
    - `name: "email"`: 5 per 15 minutes, `by: -> { params[:email_address].to_s.strip.downcase }`.
  - Both use `with: -> { render_failed_login }`.
  - Extract `render_failed_login`, which redirects with the generic alert.
- [X] T114 [US8] Create `app/controllers/registrations_controller.rb` and `app/views/registrations/new.html.erb` (R15).
  - Controller:
    - `layout "auth"` and `allow_unauthenticated_access only: %i[new create]`;
    - `before_action :redirect_if_authenticated, only: :new`;
    - `rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }`;
    - `create` calls `@user.save(context: [:create, :sign_up])` with `params.require(:user).permit(:name, :email_address, :password, :password_confirmation)`;
    - success: `start_new_session_for` and redirect to `after_authentication_url`;
    - failure: `render :new, status: :unprocessable_content`.
  - View: name, email, password and confirmation (`maxlength: 72`, autocomplete attributes), the error summary, and a "Already have an account? Sign in" link.
- [X] T115 [US8] Restyle `app/views/sessions/new.html.erb`, `app/views/passwords/new.html.erb` and `app/views/passwords/edit.html.erb` in the `auth` layout.
  - Add `layout "auth"` to `app/controllers/passwords_controller.rb`.
  - Restyle `app/views/sessions/new.html.erb`, `app/views/passwords/new.html.erb` and `app/views/passwords/edit.html.erb`: labelled fields, flash, and the "Create an account", "Forgot password?" and "Back to sign in" links.
- [X] T116 [US8] Create `app/views/layouts/auth.html.erb` and `app/assets/stylesheets/shared/auth.css`.
  - The layout uses the shared CSS, the mesh background, and a centered `ex-auth-form-card` with `brand/wordmark-160` at 80 px CSS height (alt "Dev Library").
  - The card is full-width on mobile and 440 px wide on desktop.
- [ ] T117 [US8] Wire up the icons and the PWA manifest in `app/views/layouts/_head_icons.html.erb` and `app/views/pwa/manifest.json.erb`.
  - Create `app/views/layouts/_head_icons.html.erb`: `favicon.ico`, `icon.png` (512) and `apple-touch-icon.png`, plus a manifest link to `pwa_manifest_path(format: :json)`.
  - Render it in the application, auth and reader layouts, and remove the `icon.svg` links.
  - Update `app/views/pwa/manifest.json.erb`:
    - name and short_name "Dev Library";
    - description "Read, review and keep your books.";
    - icons 192, 512 and maskable 512;
    - `theme_color` and `background_color` = the hex printed by T008.
- [ ] T118 [US8] Update `specs/001-core-data-model/contracts/sign-in.md`: the IP-limit row now returns the generic "Try another email address or password." (002 FR-050), and add the per-email bucket row and the blocked-account row with a pointer to 002.
- [ ] T119 [US8] Live-verify quickstart §4 steps 10–11, mobile then desktop, including the browser tab icon. Screenshots go to `.playwright-mcp/us8-*.png`.

**Progress (2026-10-25): branded auth pages and sign-up done; account protection still open.**

- Done: T103, T106, T114, T115, T116. Also `spec/requests/auth_pages_spec.rb` (card texts,
  links, in-card alert, signed-in redirect from sign-in).
- Partly done:
  - T112: only `redirect_if_authenticated` was added. Blocked-session handling is open.
  - T113: only `layout "auth"` and the signed-in redirect were added. The two rate-limit
    buckets and `render_failed_login` are open.
  - T119: auth pages were live-checked with Playwright on mobile 390×844, then desktop
    1440×900 (`.playwright-mcp/us8-*.png`), including sign-up end to end, the
    missing-name error, and the reset notice. Steps 10–11 (account protection) are open.
- Differences from the task text:
  - The card class is `.auth-card` (BEM, like the rest of the app), not `ex-auth-form-card`.
  - Its styles live in page-scoped `pages/auth.css`, linked only by the `auth` layout, not
    `shared/auth.css`, so other pages don't load them.
  - Flash messages render inside the card (`layouts/_auth_flash`).
  - Inputs use the canvas colour on the indigo card so they stay visible.
  - `config.action_view.field_error_proc` no longer wraps invalid fields; forms mark them
    with `.field--invalid` / `aria-invalid`.
  - T106's `link[rel=icon]` assertion moves to T117 with the icon work.
- Known gap (not from this work): `BooksController` (T085) is missing. On mobile, Turbo
  prefetches a touched book link and the request 500s, failing 3 examples in
  `spec/system/home_spec.rb` and `home_collection_spec.rb` until T085 lands.

**Checkpoint**: People can sign up, everything is branded, and accounts are protected like
DevCine and Spotsby.

---

## Phase 10: User Story 7 - Keep and favorite a book from its page (Priority: P3)

**Goal**: "Add to collection" or "Remove" and the heart on the book page, so "Your
collection" can be filled (FR-020).

**Independent Test**: Add a book, and it appears in the home row. Heart it to favorite,
unheart it and it stays in the collection. Remove it and add it back, and the reader still
resumes.

### Tests for User Story 7 ⚠️

- [ ] T120 [P] [US7] Add to `spec/models/library_spec.rb`:
  - `#state_for(book)` returns `{ in_library:, favorited: }`;
  - `:caching`: a hit runs no SQL, and add, favorite and remove each change the result.
- [ ] T121 [P] [US7] Write `spec/requests/books/library_entries_spec.rb`:
  - POST adds the book and its turbo_stream replaces `library_controls`;
  - DELETE removes it and keeps the `ReadingPosition`;
  - adding a draft, or an archived book that isn't in the library → 404 (not visible to the reader);
  - anonymous gives 302.
- [ ] T122 [P] [US7] Write `spec/requests/books/favorites_spec.rb`:
  - POST favorites the book and adds it to the library;
  - DELETE unfavorites it and keeps it in the library;
  - both replace `library_controls`;
  - anonymous gives 302.
- [ ] T123 [P] [US7] Write `spec/system/library_controls_spec.rb` inside `on_each_viewport`:
  - add → the home row shows the book;
  - the heart → filled with `aria-pressed="true"`, and the book is in the collection;
  - unheart → still in the collection;
  - remove, then add back → the reader resumes at the saved page.

### Implementation for User Story 7

- [ ] T124 [US7] Add `Library#state_for(book)` to `app/models/library.rb`. It runs one query and is cached under `[user.cache_key_with_version, "library_state", book.id]`.
- [ ] T125 [US7] Create `app/controllers/books/library_entries_controller.rb` and `app/controllers/books/favorites_controller.rb`, both with `create` and `destroy`.
  - They use `include BookScoped` and `Current.user.library.add!`, `remove!`, `favorite!` and `unfavorite!`.
  - `RecordInvalid` gives 422.
  - Create `app/views/books/_library_controls.html.erb` (`id="library_controls"`):
    - "Add to collection", or "In your collection · Remove";
    - a heart `button_to` with `aria-pressed` and the labels "Add to favorites" / "Remove from favorites".
  - Add a shared `app/views/books/library_controls.turbo_stream.erb`.
  - Render the partial in the `#library_controls` slot of `app/views/books/show.html.erb`.
- [ ] T126 [US7] Live-verify: add, heart, unheart, remove and re-add a book, and check the home row each time, mobile then desktop. Screenshots go to `.playwright-mcp/us7-*.png`.

**Checkpoint**: The collection can be built from the app itself.

---

## Phase 11: User Story 9 - Links that look right when pasted into other apps (Priority: P3)

**Goal**: A branded preview for every link. Published book links show the cover, title and
author, and nothing else is exposed (FR-046–FR-049).

**Independent Test**: A signed-out request to a published book returns only the title,
authors and image meta. Drafts, archived books and other pages redirect to the branded
sign-in page.

**⚠️ Gate**: T127–T129 (branded preview) can run any time after US8. T130 is the
constitution amendment. **T131 onward need it ratified first.**

- [ ] T127 [US9] Write `spec/helpers/link_preview_helper_spec.rb` with branded defaults:
  - `og:site_name` "Dev Library";
  - `og:title` "Dev Library";
  - `og:description` "Read, review and keep your books.";
  - an absolute `og:image` URL to `/og-image.png`, with `og:image:width` 1200 and `og:image:height` 630;
  - `og:url` = the current URL;
  - `twitter:card` `summary_large_image`;
  - a book variant that overrides title, description and image.
- [ ] T128 [US9] Create `app/helpers/link_preview_helper.rb` (`link_preview_tags(title:, description:, image_url:, type: "website")`, with branded defaults) and render it in the `<head>` of `app/views/layouts/application.html.erb` and `app/views/layouts/auth.html.erb`.
- [ ] T129 [P] [US9] Write `spec/requests/link_preview_spec.rb`:
  - `GET /session/new` has the branded og and twitter tags;
  - an anonymous `GET /` redirects to sign-in, and following it gives the branded tags.
- [ ] T130 [US9] **Constitution gate**: run `/speckit-constitution` to amend Principle VIII in `.specify/memory/constitution.md`.
  - The new exception: a signed-out preview of a **published** book, limited to title, authors and a resized cover image, with no other data and no file access. Drafts, archived and deleted books stay behind sign-in.
  - Bump the version to 1.2.0 (MINOR), with maintainer approval.
  - Update Gate 9 in `specs/002-home-and-reader/plan.md` from ⚠ to ✅ once ratified.
- [ ] T131 [P] [US9] Write `spec/models/book/published_preview_spec.rb` (depends on T130):
  - a published book → `Book::Preview` with exactly `public_id`, `title`, `authors` and `cover_blob_id`;
  - draft, archived, deleted and unknown → `nil`;
  - `:caching`: a hit, and unpublishing returns `nil` on the next read.
- [ ] T132 [P] [US9] Write `spec/requests/book_previews_spec.rb` (depends on T130):
  - a signed-out published book → 200 with og and twitter title, "by <authors>", the image URL and `og:type` book;
  - the meta refresh points to `/session/new`, and the session return-to is the book URL;
  - the body has no description, rating, category or review text;
  - a book without a cover uses `/og-image.png`;
  - draft, archived, deleted and unknown → 302 sign-in;
  - signed in → the full book page.
- [ ] T133 [P] [US9] Write `spec/requests/books/preview_images_spec.rb` (depends on T130):
  - published with a cover → 200 `image/jpeg` with `Cache-Control: public, max-age=300`;
  - no cover, draft or unknown → 404;
  - after `unpublish!` → 404;
  - the 61st request in a minute from one IP → 429.
- [ ] T134 [US9] Implement the preview data in `app/models/book.rb` (depends on T131).
  - Add the `:preview` cover variant: `resize_to_limit: [1200, 1200], format: :jpeg, preprocessed: true`.
  - `Book::Preview = Data.define(:public_id, :title, :authors, :cover_blob_id)` in `app/models/book/preview.rb`.
  - `Book.published_preview(public_id)`:
    - selects only those fields for `status = published`;
    - cached under `["book/preview", Book.catalog_version, public_id]`.
- [ ] T135 [US9] Create the public preview image endpoint `app/controllers/books/preview_images_controller.rb` and its route in `config/routes.rb` (depends on T133, T134).
  - Add `resource :preview_image, only: :show` inside the books `scope module: :books` in `config/routes.rb`.
  - Create `app/controllers/books/preview_images_controller.rb`:
    - `allow_unauthenticated_access` and `rate_limit to: 60, within: 1.minute`;
    - `Book.published_preview` → 404 unless there is a preview with a cover;
    - streams `cover.variant(:preview).processed` as `image/jpeg` with `Cache-Control: public, max-age=300`.
- [ ] T136 [US9] Create the preview page `app/views/books/previews/show.html.erb` and `app/views/layouts/preview.html.erb` (depends on T135 for `book_preview_image_url`).
  - `app/views/layouts/preview.html.erb`: head icons, `link_preview_tags` with the book values, and `<meta http-equiv="refresh" content="0;url=<%= new_session_path %>">`.
  - `app/views/books/previews/show.html.erb`: only the cover (`book_preview_image_url`, or `/og-image.png` without a cover), title, authors and a "Sign in to read" link.
  - `app/assets/stylesheets/pages/preview.css`.
- [ ] T137 [US9] Update `app/controllers/books_controller.rb` for signed-out book links (depends on T132, T134, T136).
  - `allow_unauthenticated_access only: :show`, plus `skip_before_action :set_book, only: :show, unless: :authenticated?`.
  - In `show`:
    - `authenticated?` → the existing full page;
    - else, when `Book.published_preview(params[:id])` returns a preview → set `session[:return_to_after_authenticating] = book_url(params[:id])` and `render "books/previews/show", layout: "preview"`;
    - else → `request_authentication`.
- [ ] T138 [US9] Live-verify `specs/002-home-and-reader/quickstart.md` §4 step 12.
  - Run `curl` signed out for a published book and a draft.
  - Then, through a tunnel, paste a book link into WhatsApp, Slack, iMessage and Discord.
  - Screenshots go to `.playwright-mcp/us9-*.png`.

**Checkpoint**: Shared links preview correctly, and only published-book basics are public.

---

## Phase 12: Polish & Cross-Cutting Concerns

- [ ] T139 [P] Create `script/benchmark_home.rb`, modelled on `script/benchmark_search.rb`, and run it.
  - 10,000 published books inside a rolled-back transaction.
  - Times the first `Book.recent` batch and 200 random keyset "See more" batches.
  - Prints p50 and p95. SC-001 needs p95 < 1 s.
  - Record the results in `specs/002-home-and-reader/fr-coverage.md`.
- [ ] T140 [P] Check SC-005 with a large PDF from `script/generate_large_pdf.rb`.
  - Run `ruby script/generate_large_pdf.rb tmp/large.pdf`, attach it to "Reader Test PDF" from the console, and open it through Playwright MCP.
  - Confirm `Range` requests only, and the saved page shown in under 5 s.
  - Run `bin/thrust bin/rails server` and confirm that `curl -sI -H 'Accept-Encoding: gzip' …/books/<id>/file` has no `Content-Encoding`.
  - Record the results in `specs/002-home-and-reader/fr-coverage.md`.
- [ ] T141 [P] Write `specs/002-home-and-reader/fr-coverage.md`, mapping FR-001–FR-054 and SC-001–SC-011 to the spec files and example groups that prove them, in the same format as `specs/001-core-data-model/fr-coverage.md`.
- [ ] T142 Run an accessibility pass on every screen with Playwright MCP accessibility snapshots at both viewports, and fix the findings in the affected `app/views/` templates and `app/assets/stylesheets/` files.
  - Every control labelled.
  - Focus order and visible focus.
  - Targets at least 44 px.
  - Reader controls reachable by keyboard.
  - Contrast of the reader themes.
- [ ] T143 Run `bundle exec rspec`, `bundle exec rspec --tag caching`, `bin/rubocop` and `bin/brakeman`. Fix until all are green with no new Brakeman warnings.
- [ ] T144 Run the full quickstart.md §4 with Playwright MCP, mobile then desktop, saving screenshots for every step to `.playwright-mcp/`.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)** has no dependencies. T005 waits for T001–T004.
- **Foundational (Phase 2)** depends on Setup, and blocks every story.
- **User stories (Phases 3–11)** depend on Foundational. They run in priority order: P1
  (US1, US2, US3), then P2 (US4, US5, US6, US8), then P3 (US7, US9).
- **Polish (Phase 12)** comes after the stories you intend to ship.

### User story dependencies

| Story | Depends on | Shares files with (run those tasks one after another) |
|---|---|---|
| US1 Newest books | Foundational | `home/show`, `pages/home.css`, `db/seeds.rb` (US2, US6) |
| US2 Your collection | Foundational | same as US1. Links to the reader route, which exists from T013 |
| US3 Reader | Foundational | `db/seeds.rb`. Independent of US1 and US2 (the reader opens by URL) |
| US4 Animation | **US3** (engines, settings controller) | `fixed_layout.js`, `reflowable.js`, `reader_controller.js`, `_nav` |
| US5 Book page | Foundational | `books_controller.rb` (US6, US9), `books/show` (US7) |
| US6 Search | Foundational | `books_controller.rb` (US5), `home/show` (US1) |
| US8 Sign-up, branding, protection | Foundational | `authentication.rb` (US3 T053), layouts |
| US7 Keep and favorite | **US5** (`#library_controls` slot) | `books/show` |
| US9 Previews | **US8** (auth layout) for T127–T129. **Constitution amendment (T130)** and **US5** for T131+ | `books_controller.rb`, `routes.rb`, layouts |

### Within each story

1. Specs first, and they fail.
2. Models and query objects.
3. Controllers and views.
4. JavaScript.
5. Styles and seeds.
6. Playwright live check.

Commit after each task or logical group.

### Parallel opportunities

- **Setup**: T001–T004 and T006–T012 are all `[P]`.
- **Foundational**: T014/T015, T017, T019–T023, T025–T027 are `[P]`. T016 waits for T014 and T015. T018 waits for T017. T024 waits for the CSS.
- **Within each story**, every spec task marked `[P]` can be written at once.
- **US3 has the most parallel work**: T054–T057 (controllers) and T060–T064 (CSS, outbox, input, sources) all run in parallel, with T065–T067 after them.
- **Across stories**, after Foundational: US1, US3, US5 and US8 can proceed in parallel. Keep the shared-file rule from the table above.

---

## Parallel Example: User Story 3

```bash
# All US3 specs together:
Task: "Write spec/requests/books/readers_spec.rb"
Task: "Write spec/requests/books/files_spec.rb"
Task: "Write spec/requests/books/reading_positions_spec.rb"
Task: "Write spec/requests/books/reading_directions_spec.rb"
Task: "Write spec/requests/reading_settings_spec.rb (theme, text size)"
Task: "Write spec/system/reader_spec.rb"
Task: "Write spec/system/reader_persistence_spec.rb"

# Then the independent building blocks together:
Task: "Create app/controllers/books/files_controller.rb (ActiveStorage::Streaming, Range)"
Task: "Create app/javascript/reader/outbox.js per reader-client.md §6"
Task: "Create app/javascript/reader/input.js per reader-client.md §5"
Task: "Create app/javascript/reader/sources/pdf_source.js (pdfjs-dist 6.4.299)"
Task: "Create app/javascript/reader/sources/cbz_source.js (zip.js HttpRangeReader)"
Task: "Create shared/reader_themes.css and pages/reader.css"
```

## Parallel Example: User Story 8

```bash
Task: "Write spec/models/user/blockable_spec.rb"
Task: "Write spec/requests/registrations_spec.rb"
Task: "Update spec/requests/sessions_spec.rb (two buckets, generic responses)"
Task: "Write spec/requests/blocked_session_spec.rb"
Task: "Write spec/system/sign_up_and_branding_spec.rb"
Task: "Write spec/system/account_protection_spec.rb"
```

---

## Implementation Strategy

### MVP first (User Story 1)

1. Phase 1 Setup, then Phase 2 Foundational.
2. Phase 3 (US1): home with the newest books and "See more".
3. **Stop and validate**: T028–T031 green, then T038 live check, mobile then desktop.

### First real release (all P1)

US1, then US2, then US3: home, collection, and a reader that resumes. This is the
product's core promise (constitution Principle V). Validate the quickstart §4 steps 1–3
and 6–7.

### Incremental delivery after that

1. US4 (animation), then US5 (book page and reviews), then US6 (search), then US8 (sign-up,
   branding, protection).
2. US7 (keep and favorite), then US9 (previews, once the amendment is ratified).
3. Polish: benchmarks, large-PDF check, coverage map, accessibility, full suite, full
   quickstart.

Each story ends at a checkpoint where it works and is tested on its own.

---

## Notes

- `[P]` = different files with no dependency on an unfinished task. `[USn]` maps the task
  to spec.md's user story n.
- Constitution Principle II: a task is done only when its specs pass **and** it has been
  exercised through the Playwright MCP against a running app. The per-story live-check
  tasks are the minimum.
- Every system spec runs inside `on_each_viewport`: mobile (390×844, touch) first, then
  desktop (1440×900).
- Never run installers or generators that overwrite the custom `spec/rails_helper.rb` and
  `spec/spec_helper.rb`. Back them up first if one must run.
- Vocabulary: "cape" in the request means the **cover**. "Category" inside a person's
  library means a **shelf**.
