# Research: Home Page, Book Page and Reader

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md)

All Technical Context unknowns are resolved below. Versions were checked against the npm
and RubyGems registries on 2026-10-20. Each one is at least two weeks old. **No new gems.**
The new JavaScript libraries are vendored and pinned through importmap (constitution
Principle I exception).

## R1. Reader engines: EPUB, PDF and comics

- **Decision**: two engines behind one reader controller.
  - **Reflowable EPUB → foliate-js**, vendored at commit
    `78914aef4466eb960965702401634c2cb348e9b1` (2026-05-01, MIT). It is native ESM with no
    build step. It gives:
    - `view.init({ lastLocation })` and `goTo(cfi)` for resume;
    - a `relocate` event with a whole-book `fraction` and a `cfi`;
    - the spine's `page-progression-direction` for RTL, with `goLeft`/`goRight` swapping;
    - a paginated flow and `renderer.setStyles(css)` for theme and text size;
    - a 300 ms `animated` slide that can be switched on and off live.
  - **PDF and CBZ → an in-house fixed-layout pager** (a Stimulus-driven module), fed by:
    - **pdfjs-dist 6.4.299** (2026-10-03) for PDF. Opened with `getDocument({ url,
      disableStream: true, disableAutoFetch: true })`, so pages are fetched by `Range` as
      they are needed (SC-005).
    - **@zip.js/zip.js 2.23.0** (2026-10-03) for CBZ. `HttpRangeReader` reads the zip's
      central directory, then each page image by range. There is no full download.
      `configure({ useWebWorkers: false })` avoids `blob:` workers.

    The pager owns page geometry, zoom and pan, RTL order, neighbour pre-rendering and the
    slide animation for both sources.
- **Rationale**: foliate-js is the only maintained, importmap-ready EPUB engine. Its
  fixed-layout renderer has no swipe, pinch, pan or animation, and its PDF adapter is
  labelled "highly experimental". `view.open(url)` also downloads the whole file, which is
  fine for EPUBs but not for a 500 MB PDF. Owning the fixed-layout pager keeps PDF and
  comics on one well-tested path with range loading.
- **Vendoring** (Propshaft only serves digested URLs, which breaks relative imports):
  - Libraries that load sibling files by relative URL live under a versioned public path:
    - `public/vendor/foliate-js/78914ae/` (it does `import('./paginator.js')` and
      `new URL('vendor/…', import.meta.url)`);
    - `public/vendor/pdfjs-dist/6.4.299/` (worker plus the `cmaps`, `standard_fonts`,
      `wasm` and `iccs` folders it fetches by name).
  - These are pinned with absolute `to:` paths and `preload: false`. Serving from `public/`
    also sidesteps `.mjs`: the Propshaft dev server sends no Content-Type for `.mjs`, while
    `Rack::Files` maps it correctly.
  - zip.js's root `index.min.js` is self-contained, so it goes through `vendor/javascript`
    as usual.
- **Risks**:
  - foliate-js has no releases and an unstable API. Pin the commit, and re-test with the
    reader fixtures before bumping it.
  - pdf.js has monthly api-minor changes. Pin the exact version.
  - pdf.js 6 needs Chrome 125, Safari 18 or Firefox ESR. That is within
    `allow_browser versions: :modern`.
  - Canvas memory at a high devicePixelRatio: cap the render scale at 2× and about
    16 MP per canvas.
  - If a Content Security Policy is enabled later, foliate's sandboxed `blob:` iframes need
    `frame-src blob:`.
- **Alternatives considered**:
  - epub.js 0.3.93: last release 2022, not plain ESM (bare and extensionless imports), and
    progress needs the slow `locations.generate()`.
  - foliate-js for every format: experimental PDF, whole-file download, no fixed-layout
    gestures.
  - fflate for CBZ: no random access, so the whole archive is held in memory.

## R2. CBR (RAR comics): deferred

- **Decision**: CBR books open to a clear "this comic can't be opened in the reader yet"
  state with a way back (FR-024). A later feature will extract CBR pages once on the server
  with `bsdtar`, in a background job. libarchive is already in the image through libvips,
  `libarchive-tools` adds about 240 KB, it is BSD-licensed and it reads RAR4 and RAR5. The
  extracted pages will feed the same fixed-layout pager.
- **Rationale**:
  - Browser-side RAR (libarchive.js 2.0.2, node-unrar-js 2.0.2) loads the whole archive
    into WebAssembly memory, so a 500 MB comic means a full download and 500 MB of RAM. The
    libraries have been idle since 2023–2024, and libarchive.js predates the fix for the
    RAR double-free CVE-2025-5914.
  - Server-side extraction needs a job, derived page storage and a ruling on whether a page
    cache counts as a "conversion" under Principle VII. That is a feature in itself.
  - Today no CBR can reach the catalog: there is no upload screen and the seeds have none.
- **Alternatives considered**: shipping libarchive.js now (memory, CVE, maintenance), or
  `unrar` from Debian non-free (RARLab licence).

## R3. "See more" pagination

- **Decision**:
  - "See more" is a GET link with `data-turbo-stream`. The response
    `append`s the next 50 cards to the list and `replace`s the "See more" control (with the
    next link, or nothing on the last page).
  - The **home newest list** uses a keyset cursor on `(published_at, id)`
    (`Book::Recent`), so a book published or deleted between loads cannot cause a repeat or
    a gap (FR-004, SC-006).
  - **Search results** keep offset pages (relevance order cannot be keyset-paged cheaply)
    plus `per + 1` look-ahead. Each card's id is `dom_id(book)`, and Turbo's `append`
    replaces a child whose id already exists, so a shifted page never shows a book twice
    (FR-011). That also absorbs double clicks.
  - The link does not use `data-turbo-action="advance"`, because a reload would then show
    only page N. Back restores Turbo's snapshot with the appended cards.
- **Alternatives considered**: nested lazy Turbo Frames (they nest deeper with every page,
  break the flat CSS grid, and need unique ids per page); infinite scroll (the user asked
  for a "See more" button).

## R4. Page-turn animation and the instant mode

- **Decision**:
  - **Fixed-layout pager**: a Web Animations API slide of the page track (`transform:
    translateX`, compositor-only), **250 ms ease-out**. Forward moves the page toward the
    reading start side: left in LTR, mirrored in RTL.
    - Interruptible: new input calls `finish()` on the running animation, then starts the
      next one, so quick taps never skip pages or leave a page half-turned (FR-031).
    - A swipe follows the finger and settles with the same curve.
    - Neighbour pages are pre-rendered, so the next page is ready when the slide starts.
  - **EPUB**: foliate's own `animated` attribute, set or removed live. Foliate's swipe is
    used inside the content iframe.
  - **Effective animation** = the account setting **and not** `prefers-reduced-motion:
    reduce` (FR-035). foliate ignores reduced motion, so the controller simply never sets
    `animated` in that case.
  - **Instant mode**: no animation object at all. The page swaps in the same frame as the
    input (SC-004 < 100 ms).
  - Test hooks: the reader root exposes `data-reader-animation="slide|none"` and toggles
    `data-reader-turning` during a slide.
- **Rationale**: one curve and one direction rule across engines, with interruption
  handled by the code that owns the DOM.
- **Alternatives considered**: same-document View Transitions. They are baseline since
  October 2025, but:
  - hit-testing goes to the document element during a transition, so taps are swallowed;
  - the update callback pauses rendering, with an implementation-defined timeout;
  - Safari and Firefox capture of canvas and sandboxed-iframe content is unverified;
  - combining them with foliate's own slide is unsupported.

  A page-curl effect was also rejected: heavy, and it obscures text on small screens.

## R5. Never losing a position (FR-023, Principle V)

- **Decision**: a single-entry **outbox** per user and book.
  - Every `relocate` writes `{ location, progress, read_at }` (device time, ISO 8601) to
    `localStorage["devlibrary:reading-position:<user_id>:<public_id>"]`, then sends it.
  - **Send**: `fetch(PATCH, { keepalive: true })` with JSON, `X-CSRF-Token` from the meta
    tag, and `Accept: application/json`.
  - **Coalescing**: one request in flight. Turns made meanwhile replace the pending entry,
    and the latest is sent when the request finishes.
  - **When it flushes**:
    - after every turn;
    - on `visibilitychange` → hidden, with `pagehide` as a backup;
    - in the Stimulus `disconnect()`, because Turbo navigation fires neither event;
    - on the `online` event.
  - **Responses**:
    - `204` → clear the entry if it is still the same `read_at`;
    - network error or `5xx` → retry with backoff (1 s, doubling to 30 s);
    - `401` → keep the entry and show "Sign in again to keep saving your place" (sign-in
      returns to the reader, which flushes on connect);
    - `404` → drop the entry and show "not available";
    - `422` → drop it.
  - **Resume**: the server renders the saved position. If the outbox holds a newer
    `read_at` (pages turned offline before the tab closed), the reader starts there and
    flushes it.
  - Server newest-wins (`ReadingPosition.record!`, 001 R8) makes every retry and
    out-of-order delivery safe.
- **Server change**: `Authentication#request_authentication` answers `head :unauthorized`
  for JSON requests instead of redirecting. Otherwise `fetch` would follow the redirect and
  read the sign-in page's `200` as success. HTML behaviour is unchanged.
- **Constitution note**: the outbox only holds a write that has not reached the server yet.
  The server stays the source of truth, so this is not an application-state store
  (Principle I). It is recorded in Complexity Tracking anyway.
- **Alternatives considered**: `sendBeacon` (POST only, no headers; it would need
  `authenticity_token` plus `_method=patch` form bodies); save only on unload (misses
  crashes and backgrounded tabs on mobile).

## R6. Delivering the book file

- **Decision**: `Books::FilesController#show` includes `ActiveStorage::Streaming`.
  - Every request resolves the book through `find_visible_cached!`, so the session cookie
    authorizes each range request.
  - A single `Range` is answered with `send_blob_byte_range_data` (206). Anything else uses
    `send_blob_stream`.
  - Always sends `Accept-Ranges: bytes`, `Content-Length`, `Cache-Control: private,
    no-store` and no `Content-Encoding`. Thruster's gzip must not touch `application/pdf`
    or zip: check this in the request spec and the live check.
- **Rationale**: pdf.js only switches to range mode when it sees `Accept-Ranges` and
  `Content-Length`. Active Storage's Disk controller never sends `Accept-Ranges`. The proxy
  controller marks full responses `public` forever, which is wrong for private books.
  Short-lived signed URLs (the earlier idea) expire in the middle of a long reading session
  while pdf.js is still fetching ranges.
- **Alternatives considered**: redirecting to `rails_storage_proxy_path(expires_in:)`
  (expiry mid-session, public caching); `send_file` (no Active Storage service
  abstraction).

## R7. Where reading settings live

- **Decision**: three columns on `users` (`reader_page_animation`, `reader_theme`,
  `reader_text_size`) behind a `User::ReadingSettings` concern. See
  [data-model.md](data-model.md).
- **Rationale**: `Current.user` is loaded on every request, so the reader gets its
  settings with no query and no cache entry. The 001 Complexity Tracking already excludes
  authentication lookups from `Rails.cache`, and settings ride along on the same row. A
  change bumps `users.updated_at`, which every per-user cache key embeds.
- **Alternatives considered**: a `reading_settings` table (an extra query or cache entry
  per reader load, plus creation on sign-up); browser storage (not on the account, so it
  breaks FR-032 across devices).

## R8. Rich-text editor and emoji picker for reviews

- **Decision**:
  - **Trix 2.1.19**, already installed and pinned.
  - **emoji-picker-element 1.29.1**, with data from **emoji-picker-element-data 1.8.0**
    (`en/emojibase/data.json`, 440 KB, about 72 KB gzipped), self-hosted.
    - It sits in a Stimulus popover controller next to the Trix toolbar.
    - It is loaded with `import()` the first time the popover opens, from
      `public/vendor/emoji-picker-element/1.29.1/` (its `index.js` imports
      `./picker.js` and `./database.js` relatively), with `data-source` pointing at the
      self-hosted JSON.
    - Insertion: save `editor.getSelectedRange()` when the picker opens, then
      `setSelectedRange` + `insertString(unicode)`.
    - The phone's own emoji keyboard keeps working.
- **Rationale**:
  - Trix is small (about 52 KB gzipped), already wired to Action Text, and has a documented
    insert API.
  - Lexxy 1.0.0 is stable, but on Rails 8.1 it monkey-patches Action Text's helpers (the
    clean `config.action_text.editor = :lexxy` switch arrives in Rails 8.2). It weighs
    about 196 KB and has no documented insert API. Both editors store emoji as plain
    Unicode in Action Text's canonical HTML, so moving to Lexxy later needs no data
    migration.
  - The picker gives search, skin tones and keyboard and screen-reader support.
- **Alternatives considered**: a curated 50-emoji Stimulus picker (no search); relying only
  on the OS emoji keyboard (hidden on desktop).

## R9. App-wide Turbo modal (Principle I)

- **Decision**:
  - The layout holds `<dialog data-controller="modal">` wrapping `turbo_frame_tag "modal"`.
    Links open it with `data: { turbo_frame: "modal" }`, and `edit` views render inside that
    frame.
  - `turbo:frame-load` → `showModal()`. `turbo:submit-end` with success → close. A
    `turbo_stream.update "modal"` with empty content also closes it.
  - Validation errors: `render :edit, status: :unprocessable_content` (Rack 3.2's name for
    422) keeps the dialog open with errors.
  - On close, clear the frame and remove its `src`, so the same link reopens it. Also close
    and clear on `turbo:before-cache`, so snapshots never contain an open dialog.
- **Gotcha**: never `redirect_to` from inside the frame (`turbo:frame-missing`). Use
  streams.
- **Inline exception**: the review **create** form sits inline on the book page, because
  the request asks for it there and there is no `new` route. **Edit** uses the modal.

## R10. Design system implementation (Principle IV)

- **Decision**:
  - `app/assets/stylesheets/shared/`: `tokens.css` (every `DESIGN.md` color, spacing,
    radius and type token as a CSS custom property), `fonts.css`, `base.css`, `buttons.css`,
    `cards.css`, `forms.css`, `nav.css`, `modal.css`, `stars.css`, `reader_themes.css`
    (light, sepia and dark reading-surface tokens).
  - Page styles go in `app/assets/stylesheets/pages/` (`home.css`, `books.css`,
    `reader.css`) and load only on their page through `content_for :stylesheets`.
  - The layout links the shared files explicitly instead of `stylesheet_link_tag :app`,
    which would load every page's CSS everywhere.
  - Fonts are self-hosted WOFF2 (OFL), following `DESIGN.md`'s open substitutes: **Hanken
    Grotesk** 700/800 for display and **Inter** 400/500/600 for body. Self-hosting keeps
    the PWA usable offline and avoids a third-party request on every page.
  - Icons (heart, star, search, settings, chevrons, close) are inline SVG through an `icon`
    helper, copied from Lucide (ISC).
  - The animated gradient mesh is CSS only, behind the home and book pages. It is static
    under reduced motion, and absent from the reader (FR-030).
  - Green is reserved for the book page's "Read" CTA. Card "Read" buttons use the compact
    ghost style.
- **Alternatives considered**: Google Fonts CDN (third-party request, offline PWA);
  Tailwind (not in the stack; tokens must trace to `DESIGN.md`).

## R11. Mobile surfaces (Principle III)

- **Decision**:
  - Enable the PWA manifest: uncomment the route, add the link tag, and set the theme and
    background colors to the canvas indigo instead of the placeholder red. The service
    worker stays a stub.
  - Verify mobile in Chrome's **mobile emulation** (390×844, touch enabled, coarse pointer)
    for system specs and Playwright, then desktop.
  - There is no Hotwire Native app yet. Its verification is deferred (Complexity Tracking),
    as in 001.
- **Alternatives considered**: a plain 390-px window without touch. That cannot exercise
  swipe or pinch.

## R12. Reader input: tap, swipe, keys, zoom (FR-025, FR-028)

- **Decision**:
  - **Tap zones**: the outer 30% on each side turns the page, the middle toggles the
    toolbar. Zones map through the effective direction: in RTL the left edge is "next".
  - **Swipe** (pointer events): at least 40 px horizontally, within 30° of horizontal.
  - **Keys**:
    - ArrowRight and ArrowLeft are visual (in RTL, ArrowLeft is next);
    - PageDown and Space are next, PageUp and Shift+Space are previous, whatever the
      direction.
    - Keys are listened for on the document and inside foliate's iframes (through its
      `load` event's `doc`).
  - **Zoom** (fixed-layout only):
    - pinch with two pointers, double-tap to toggle 2×, Ctrl/⌘ + wheel, and +/− buttons;
    - while zoomed, one-finger drags pan and page turns pause;
    - "Fit" returns to fit-page.
  - Touch targets are at least 44 px.
- **Alternatives considered**: relying on browser pinch-zoom (it zooms the toolbar too
  and fights the swipe handler).

## R13. Covers

- **Decision**:
  - Named variants `:card` (240×360 fill) and `:large` (600×900 limit), WebP,
    `preprocessed: true`, so they are generated by a job on attach.
  - `with_attached_cover` already preloads the variant records in Rails 7.1+.
  - Images use `loading="lazy"` and `decoding="async"`, with width and height set to avoid
    layout shift.
  - A `cover_image_tag` helper signs URLs with an expiry rounded to the hour window
    (`expires_at:`). Without that, `urls_expire_in = 1.hour` would produce a new URL on
    every render and defeat the browser cache.
  - **Verify while implementing**: the rounded `expires_at` path is inferred from the
    Active Storage source, not yet tested. If it does not hold, fall back to a
    session-authorized `Books::CoversController` with `Cache-Control: private, max-age`.
- **Alternatives considered**: unsigned permanent cover URLs. Covers are not "book files"
  under Principle VIII, but every Active Storage route already requires a session, and
  keeping URLs short-lived is the safer default.

## R14. Testing approach (Principle II)

- **Decision**:
  - **Model specs**: `Book::Recent` (keyset order, look-ahead, bad cursor, publish between
    pages), `Book.search_page`, `Book.find_visible_cached!`, `Library#state_for`,
    `Review.by` and `User::ReadingSettings`, plus `:caching` examples for each new key (hit
    path runs no SQL; a write changes the result).
  - **Request specs**: one per controller, covering every row and every negative-auth case
    in [contracts/http.md](contracts/http.md), including `Range` behaviour on the file
    endpoint and 401 for JSON when signed out.
  - **System specs**: per story, wrapped in `on_each_viewport`. Mobile runs with Chrome
    mobile emulation (touch), which needs a small extension to
    `spec/support/system_viewports.rb`.
    - Network loss: `driver.network_conditions = { offline: true }`.
    - Reduced motion: CDP `Emulation.setEmulatedMedia`.
    - Reader assertions read `data-reader-location`, `data-reader-progress` and
      `data-reader-animation` rather than pixels.
  - **Reader fixtures**: generated by `script/generate_spec_fixtures.rb` (stdlib + `zip`)
    into `spec/fixtures/files/reader/`:
    - `text-6-pages.pdf`: each page prints its number;
    - `reflowable-3-chapters.epub`: enough text to paginate at both viewports;
    - `comic-4-pages.cbz`: distinct solid-colour PNG pages;
    - `manga-rtl-4-pages.cbz`: same, seeded as `kind: manga`.

    `script/generate_large_pdf.rb` writes the ~500 MB SC-005 file on demand. It is never
    committed.
  - **Live**: each task ends with the Playwright MCP run in [quickstart.md](quickstart.md)
    §4, mobile first.

## R15. Sign-up (US8, FR-039–FR-042)

- **Decision**: `RegistrationsController` with `new` and `create`, mirroring Spotsby's.
  - `allow_unauthenticated_access`, plus `before_action :redirect_if_authenticated, only:
    :new`.
  - `rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to
    new_registration_path, alert: "Try again later." }`.
  - It saves with `@user.save(context: [:create, :sign_up])`, so the 001 `:sign_up` name
    rule applies.
  - Strong params `user: [:name, :email_address, :password, :password_confirmation]`.
    `role` is never permitted.
  - Success: `start_new_session_for(@user)`, then `redirect_to after_authentication_url`.
  - Failure: `render :new, status: :unprocessable_content`. The name and email stay in the
    form; password fields are always rendered empty.
  - `redirect_if_authenticated` is added to the `Authentication` concern. It also guards
    `sessions#new` (FR-042).
- **Layout**: a new `auth` layout serves sessions, registrations and passwords. It is a
  centered card with the full logo on top and no nav bar (FR-043).
- **Alternatives considered**: has_secure_password plus a hand-rolled form on the sessions
  page (mixes two flows); a sign-up gem (no gems; the 001 rules already exist).

## R16. Brand assets: header, auth pages, favicon, app icons (FR-037, FR-043, FR-044)

- **Decision**: a one-off `script/generate_brand_assets.rb` uses the `vips` CLI (already
  installed, and in the Dockerfile as libvips) to derive committed files from the four
  sources in `app/assets/images/`. The sources are 400 KB–1.2 MB with wide transparent
  padding, so nothing renders them directly.
  - **Header and auth wordmark**: `app/assets/images/brand/wordmark.webp` and a PNG
    fallback, trimmed to content. 64 px tall for the header (shown at 32 px CSS) and 160 px
    tall for the auth card (shown at 80 px CSS). From `logo_with_text.png`, whose white
    "Dev" reads on the indigo canvas.
  - **Favicon** (from `logo_without_text.png`, trimmed, transparent):
    `public/favicon.ico` (16 and 32), `public/icon.png` (512), `public/icon-192.png`.
  - **Home-screen icon** (from `logo_without_text_with_bg.png`):
    - `public/apple-touch-icon.png` (180, opaque, so iOS adds no black box);
    - `public/icon-maskable.png` (512, mark inside the 80% safe zone).
  - The default `public/icon.svg` (the red circle) is deleted, along with its `<link>`.
  - PWA manifest: name "Dev Library", `theme_color` and `background_color` = the
    with-bg logo's background, icons 192, 512 and maskable 512.
  - Icons stay in `public/` at stable, undigested paths, because browsers, iOS and preview
    bots request them by fixed name without a session.
- **Alternatives considered**: hand-exporting each size (not reproducible); an SVG favicon
  (the sources are raster, and embedding a PNG in SVG gains nothing).

## R17. Link previews (US9, FR-046–FR-049)

- **Decision**:
  - **Branded preview everywhere**:
    - the `application` and `auth` layouts render Open Graph and Twitter meta from a
      `link_preview` helper: `og:site_name` "Dev Library", `og:title`, `og:description`
      (the tagline: "Read, review and keep your books."), `og:type`, `og:url`, and
      `og:image` = `/og-image.png`;
    - `/og-image.png` is a 1200×630 PNG from `logo_with_text_with_bg.png`, padded with its
      own background colour by the R16 script, committed to `public/`;
    - `twitter:card` = `summary_large_image`.

    Preview bots that hit any signed-in page are redirected to sign-in, and almost all of
    them follow redirects, so they read the branded tags there (FR-046, FR-048).
  - **Book previews**: a **signed-out** `GET /books/:public_id` for a **published** book
    renders a minimal public page (`books/previews/show`, `preview` layout, status 200). It
    carries:
    - `og:title` = title, `og:description` = "by " + authors, `og:image` = the book's
      preview image URL (or `/og-image.png` without a cover), `og:type` = "book";
    - a body showing only the cover, title, authors and a "Sign in to read" link;
    - `<meta http-equiv="refresh" content="0;url=/session/new">`, with the return-to set
      server-side, so a person's browser goes straight to sign-in and then to the book
      (FR-049).

    Draft, archived and deleted books, and every other route, keep the 302 to sign-in, so
    they reveal nothing (FR-048). Only published books get a 200. Draft and deleted are
    indistinguishable.
  - **Preview image**: `GET /books/:public_id/preview_image`
    (`Books::PreviewImagesController`, `allow_unauthenticated_access`):
    - serves the cover's `:preview` variant (`resize_to_limit: [1200, 1200]`, JPEG, because
      some preview apps reject WebP) for published books only, otherwise 404;
    - `Cache-Control: public, max-age=300`, so an unpublished book's image stops loading
      within 5 minutes (FR-048);
    - per-IP `rate_limit to: 60, within: 1.minute`.
  - **Lookup**: `Book.published_preview(public_id)` returns a small cached struct (`title`,
    `authors`, `public_id`, `cover` present?, `cover` blob id). Key: `["book/preview",
    Book.catalog_version, public_id]`. It never touches the description, reviews or
    rating, so nothing else can leak through the template (FR-047).
  - **Requires** the constitution Principle VIII amendment (spec Assumptions). It must be
    ratified before these routes ship. Until then, the US9 tasks are blocked.
- **Alternatives considered**:
  - user-agent sniffing of known preview bots (brittle; iMessage and others spoof UAs, and
    new apps would get nothing);
  - signed public Active Storage URLs for the preview image (the session guard covers
    every Active Storage route; adding an unauthenticated hole there is broader than one
    controller);
  - oEmbed (not read by WhatsApp or iMessage).

## R18. Account protection, as in DevCine and Spotsby (FR-050–FR-054)

- **Decision**:
  - **Two sign-in buckets** on `SessionsController#create`. Both answer with the same
    generic redirect as a wrong password (`render_failed_login`), so neither limit is
    advertised:
    - `rate_limit to: 10, within: 3.minutes, name: "ip"`;
    - `rate_limit to: 5, within: 15.minutes, name: "email", by: -> {
      params[:email_address].to_s.strip.downcase }`.

    This replaces 001's "Try again later." for the IP limit (FR-050). The 001 contract and
    `spec/requests/sessions_spec.rb` are updated to match.
  - **Blocked accounts**: a nullable `users.blocked_at` column behind a `User::Blockable`
    concern, with `blocked?`, `block!` and `unblock!`.
    - It is kept separate from `role`, unlike DevCine's `blocked` role value. A role change
      would lose "was admin", and 001 constrains `role` to reader/admin.
    - `block!` sets `blocked_at` and destroys every session in one transaction.
    - `User.authenticate_with_lockout` returns `nil` for a blocked account. It still runs
      `authenticate` for timing parity, and does not count the failure (FR-054).
    - The password-change callback clears the lockout only, never `blocked_at` (FR-051).
  - **Existing sessions**: `Authentication#resume_session` treats a session whose user is
    blocked as invalid.
    - It destroys the session and clears the cookie.
    - HTML: redirect to sign-in with the alert "Your account has been blocked."
    - JSON: `403 Forbidden`. The reader outbox drops the entry and shows a blocked state.
    - Because Active Storage controllers include `Authentication`, blocked users also lose
      file access (FR-052).
  - **Lock email**: when `register_failed_sign_in!` starts a new lock (inside its row lock,
    on the transition only), it calls `PasswordsMailer.locked(user).deliver_later`. The
    email explains the lock and carries the standard reset link (`edit_password_url(token)`).
    It is skipped for blocked users, and attempts during a lock don't re-send it (FR-053,
    FR-054). Subject: "Your Dev Library account was locked: reset your password to unlock it".
  - **Maintainers** block and unblock from the console (`User.find_by(email_address:
    …).block!`). No admin screen in this feature.
- **Kept from 001**: the 5-failure escalating timed lock (15 min doubling to 24 h). DevCine
  and Spotsby lock until a reset after 15 failures. A lock that never expires lets an
  attacker shut a person out indefinitely (001 R6).
- **Alternatives considered**: Rack::Attack (extra gem; the Rails 8 `rate_limit` is what
  DevCine and Spotsby use); a `blocked` role value (loses the role, breaks the 001 check
  constraint).

## Sources

- foliate-js: <https://github.com/johnfactotum/foliate-js>
- pdf.js releases: <https://github.com/mozilla/pdf.js/releases> · range rules: <https://github.com/mozilla/pdf.js/blob/master/src/display/network_utils.js>
- zip.js: <https://github.com/gildas-lormeau/zip.js>
- epub.js: <https://github.com/futurepress/epub.js>
- libarchive.js: <https://github.com/nika-begiashvili/libarchivejs> · Debian `libarchive-tools`: <https://packages.debian.org/trixie/libarchive-tools> · CVE-2025-5914: <https://osv.dev/vulnerability/CVE-2025-5914>
- View Transitions: <https://drafts.csswg.org/css-view-transitions-1/> · <https://developer.chrome.com/docs/web-platform/view-transitions/same-document>
- Lexxy 1.0: <https://dev.37signals.com/lexxy-1-0/> · Trix: <https://github.com/basecamp/trix>
- emoji-picker-element: <https://github.com/nolanlawson/emoji-picker-element>
- Turbo frames and streams: <https://turbo.hotwired.dev/handbook/streams> · events: <https://turbo.hotwired.dev/reference/events>
- Active Storage streaming: <https://github.com/rails/rails/blob/v8.1.4/activestorage/app/controllers/concerns/active_storage/streaming.rb>
- `fetch` keepalive: <https://developer.mozilla.org/en-US/docs/Web/API/RequestInit#keepalive>
