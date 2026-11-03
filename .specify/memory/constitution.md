<!--
SYNC IMPACT REPORT
==================
Version change: 1.0.0 → 1.1.0
Bump rationale: MINOR. Materially expanded guidance, no principles removed:
  - VI. Content-Aware Rendering: manga defaults to right-to-left; admins may change a
    book's default direction; readers may switch direction in the reader, saved per user
    per book.
  - VII. Format Fidelity & Safe Conversion: conversion targets stated as PDF and EPUB only.
  - VIII. Role-Based Catalog Authority: whole app (including search) requires sign-in;
    sign-in page is the entry point; anonymous-redirect specs required on every endpoint.
  - Quality Gate 9 extended to match Principle VIII.

Prior version (unratified template → 1.0.0, MAJOR): initial ratification. Structure and
engineering principles adapted from the DevCine constitution v1.1.1 and re-targeted from
video streaming to reading.

Principles in 1.0.0 (relative to the DevCine reference):
  - I. Hotwire/Turbo-First Architecture (kept; adds a documented exception for
    document-rendering libraries wrapped in Stimulus)
  - II. Comprehensive Test Coverage (NON-NEGOTIABLE) (kept; adds reader fixture coverage)
  - III. Mobile-First, Multi-Platform Parity (kept; adds touch + keyboard reader control)
  - IV. Design System Fidelity (kept; adds reading-surface legibility rule)
  - V. Uninterrupted Playback → V. Reading-First Continuity (NON-NEGOTIABLE) (redefined)
  - VI. Content-Aware Rendering (new)
  - VII. Format Fidelity & Safe Conversion (new)
  - VIII. Role-Based Catalog Authority (new)
  - IX. Cache-by-Default with Automatic Invalidation (kept from DevCine VI; adds rule that
    binary files never enter Rails.cache)

Added sections: Technology & Architecture Standards, Development Workflow & Quality Gates
Removed sections: None (template placeholders only)

Templates requiring updates:
  ✅ .specify/templates/plan-template.md (Constitution Check derives gates from this file
    generically; no edit required)
  ✅ .specify/templates/spec-template.md (no principle enumeration; no edit required)
  ⚠ .specify/templates/tasks-template.md (states "Tests are OPTIONAL"; this conflicts with
    Principle II. Principle II explicitly overrides it, so tests are REQUIRED in every
    generated tasks.md. The template was not edited by this command.)

Follow-up TODOs: None
-->

# DevLibrary Constitution

## Core Principles

### I. Hotwire/Turbo-First Architecture

All interactive behavior MUST be implemented with the Hotwire/Turbo stack (Turbo
Drive, Turbo Frames, Turbo Streams, and Stimulus) as the default strategy; custom
client-side JavaScript frameworks (React, Vue, Svelte, and similar) are prohibited
without an explicit, documented exception. Creating and editing records (`new` and
`edit` routes) MUST be presented in a modal that is Turbo-rendered and available
consistently from any page. Server responses MUST drive UI updates via Turbo Streams
rather than bespoke client logic.

**Documented exception (reader engines)**: Rendering PDF and EPUB content in the browser
requires a document-rendering library (for example a PDF renderer or an EPUB renderer).
Such libraries are permitted ONLY when they are pinned through importmap, wrapped in a
Stimulus controller, and confined to rendering book content. Application state (library
membership, reading position, bookmarks, conversion status) MUST still flow through Rails
endpoints and Turbo Streams, never through a client-side store.

**Rationale**: A single, consistent rendering strategy keeps the app fast, reduces
JavaScript surface area, and guarantees the modal-based CRUD experience behaves
identically everywhere. The reader exception is narrow, so it cannot grow into a
parallel front-end architecture.

### II. Comprehensive Test Coverage (NON-NEGOTIABLE)

Every feature and every task MUST ship with automated tests written in RSpec. The
minimum coverage is:

- **Backend**: request/controller specs and model specs for all business logic and
  endpoints, including background jobs (conversion, metadata extraction).
- **Frontend & behavior**: system specs driven by Capybara with the Selenium driver
  for user-facing flows (including Turbo modal interactions and the reader).
- **Reader fixtures**: any change to reading, conversion, or download MUST be exercised
  against committed fixture files covering at least a reflowable EPUB, a text PDF, an
  image-based comic, and a right-to-left manga.

In addition, every completed task MUST be exercised and confirmed working through the
Playwright MCP against a running instance before it is considered done. A task with
failing or absent tests is not complete. Tests MUST be authored alongside (or before)
the implementation they cover. This principle overrides any template default that marks
tests as optional.

**Rationale**: A reader has many moving parts (rendering, page turns, progress sync,
conversion, modals, streams). Only layered automated coverage plus live MCP verification
keeps regressions out.

### III. Mobile-First, Multi-Platform Parity

The application is mobile-first. Every UI change MUST be designed and verified on
mobile first, via the PWA and Hotwire Native presentation, before being verified on
desktop. Desktop and mobile MUST present the same information and capabilities and feel
cohesive. They MAY differ in layout (similar, not identical). The reader MUST be fully
operable by touch on mobile (tap zones and swipe for page turns, pinch-zoom on
fixed-layout pages) and by keyboard on desktop (arrow keys and page keys). A change
that only works or has only been checked on desktop is incomplete.

**Rationale**: Most reading happens on phones and tablets. Designing for the constrained,
touch-driven surface first keeps desktop-only assumptions out of the app.

### IV. Design System Fidelity

`DESIGN.md` is the single source of truth for visual language, tokens, color, motion,
and component patterns; all styling decisions MUST trace back to it. CSS MUST be
scoped per page (page-specific stylesheets), while cross-cutting concerns such as
typography, variables, and other shared tokens MUST live in a `shared/` folder and be
reused rather than duplicated. Hard-coded values that bypass shared tokens are prohibited.

The reading surface (the area where book content renders) is the one place where
legibility outranks brand expression. Reader themes (at minimum light, sepia, and dark)
MUST be defined as shared tokens. Decorative motion, gradient meshes, and overlapping art
MUST NOT render behind or over book content. Reader chrome (toolbars, menus, progress
bar) still follows `DESIGN.md`.

**Rationale**: Centralized tokens plus page-scoped styles keep the energetic
indigo/Blurple aesthetic consistent and prevent style drift. Protecting the reading
surface keeps long reading sessions comfortable.

### V. Reading-First Continuity (NON-NEGOTIABLE)

Reading is the core purpose of DevLibrary. The following rules are non-negotiable:

- **Read immediately**: Any readable book a user can see (in search results, the catalog,
  or their personal library) MUST open in the in-app reader with one action. Reading MUST
  NOT require downloading the file first or adding it to the personal library.
- **Automatic position tracking**: The user's last-read position MUST be persisted
  automatically on every page turn or location change, with no explicit save action. The
  position MUST use a format-appropriate locator: a page index for PDF and image-based
  formats, and an EPUB CFI for reflowable EPUB.
- **Resume everywhere**: Reopening a book MUST resume at the last persisted position on
  any surface (web, PWA, Hotwire Native) for the same user.
- **Never lose a position**: No navigation, app backgrounding, screen lock, page
  unload, or transient network failure may discard a position update. Failed saves MUST
  be retried, and the most recent position MUST win.
- **User marks are durable**: Bookmarks and reading progress (e.g. percentage and "last
  read" timestamp) are per-user records and MUST survive sessions, devices, and book
  re-conversion.

Any feature touching the reader MUST include tests and live verification of position
persistence and resume.

**Rationale**: Opening straight into reading and always resuming at the right page is the
product's defining promise. A lost position breaks trust faster than any other defect.

### VI. Content-Aware Rendering

DevLibrary reads books, comics, Japanese manga, storybooks, and similar works. Every
catalog item MUST record its content type and reading direction as metadata, and the
reader MUST render according to that metadata:

- **Reflowable text** (most novels and non-fiction EPUBs) MUST support adjustable font
  size and reader theme, and MUST reflow to the viewport.
- **Fixed-layout and image-based content** (comics, manga, storybooks, picture-heavy PDFs)
  MUST preserve original page geometry and support zoom and pan. Wide viewports MAY show
  two-page spreads.
- **Reading direction** MUST be honored: right-to-left works MUST turn pages, order
  spreads, and map swipe and tap gestures right-to-left.
- **Direction is a default, not a lock**: Manga MUST default to right-to-left; other
  content types default to left-to-right. Admins MAY change a book's default direction.
  Readers MUST be able to switch direction from inside the reader, and that choice MUST
  be saved per user per book and restored on every surface.

**Rationale**: A single text-oriented reader mangles comics and manga. Making layout and
direction explicit metadata keeps each form readable as its creators intended.

### VII. Format Fidelity & Safe Conversion

PDF and EPUB are the first-class formats: every book MUST be readable in-app and
downloadable in its original format. Conversion targets are PDF and EPUB only. Other
formats (for example CBZ/CBR for comics) MAY be accepted for upload and reading, but
adding any other conversion target requires an amendment.

- **Validate uploads by content**: Uploaded files MUST be validated by their actual
  content (signature/MIME sniffing), not by file extension, and rejected if unreadable.
- **Originals are immutable**: Conversion MUST NOT modify or replace the original upload.
  Converted outputs are stored as separate derived attachments linked to their source.
- **Convert out of band**: Conversion MUST run in a background job, never inside a web
  request. Progress, completion, and failure MUST be pushed to the user via Turbo Streams.
- **Reuse conversions**: A conversion for a given source file version and target format
  MUST run at most once. Later requests reuse the stored output until the source
  changes.
- **Preserve what matters**: Converted output MUST keep page order, reading direction,
  and core metadata (title, author(s), cover). It MUST be validated (it opens in the
  DevLibrary reader and passes a structural check for the target format) before it is
  offered for reading or download.

**Rationale**: Users rely on download and conversion to take books elsewhere. Validating
inputs, protecting originals, and verifying outputs keeps every file a user receives
trustworthy, while background processing keeps the app responsive.

### VIII. Role-Based Catalog Authority

DevLibrary is available only to signed-in users. Only administrators may add, edit,
replace, or remove catalog books and their files. Signed-in users MAY search the catalog,
read, download, request conversions, and manage their own personal library, bookmarks,
and reading progress.

- **Sign-in first**: Every page and endpoint, including search, MUST require an
  authenticated session. The only exceptions are the authentication flows themselves
  (sign-in, plus password reset or registration if those exist). Visitors without a
  session MUST land on the sign-in page, which is the app's entry point on every surface.
- **Server-side enforcement**: Authentication and authorization MUST be enforced in
  controllers and jobs on every request. Hiding a button is never sufficient.
- **Negative tests required**: Every endpoint MUST have request specs proving anonymous
  requests are redirected to sign-in, and every admin-only endpoint MUST also have specs
  proving non-admin requests are rejected.
- **Personal data isolation**: Personal libraries, bookmarks, and reading progress MUST be
  scoped to their owner and MUST NOT be readable or writable by other users.
- **No permanent public file URLs**: Book files and converted outputs MUST be served
  only through authorized endpoints or short-lived signed URLs.

**Rationale**: A curated catalog depends on a single trusted source of uploads, and a
personal library is private by nature. Enforcing both on the server keeps the guarantees
real.

### IX. Cache-by-Default with Automatic Invalidation

Read access to persisted data MUST be cached. Every model query that serves a read,
whether a single record or a collection (books, authors, series, genres, catalog search
results, personal libraries, and any other model), MUST be served through `Rails.cache`
rather than hitting the database on every request. `Rails.cache` (e.g.
`Rails.cache.fetch`) is the single, mandatory caching mechanism: all cache reads and
writes MUST go through it. Other caching mechanisms (view/fragment caching helpers,
per-request memoization as a substitute, or bespoke in-memory stores) MUST NOT be used in
its place. The following rules are non-negotiable:

- **Cache on read**: Reads MUST go through `Rails.cache.fetch` (or an equivalent
  `Rails.cache` call) keyed by a deterministic, version-aware key derived from the model
  and its identity plus version (e.g. `cache_key_with_version`, record `id` +
  `updated_at`, or a collection key incorporating `count` and `max(updated_at)`).
  Per-user data MUST include the user's identity in the key.
- **Invalidate on write**: Any create, update, or destroy MUST expire (stale) the cache
  for the affected record AND for every associated record or collection whose cached view
  includes it. Uploading a new book MUST stale that book's cache and the caches of its
  authors, series, genres, search results, and any collection that lists it. Changing a
  genre MUST stale that genre's cache and every collection derived from it. Adding a book
  to a personal library or updating reading progress MUST stale that user's library
  caches. The same cascade applies to all other records.
- **Automatic, not ad-hoc**: Invalidation MUST be wired through model callbacks
  (`after_commit`) and/or `touch:` associations so it cannot be forgotten at a call site.
  Manual, scattered cache-busting is prohibited.
- **No stale reads after a committed write**: A read issued after a write commits MUST
  reflect that write. Correctness always wins over cache retention. A resumed reading
  position MUST never be older than the last committed position.
- **Metadata only**: Binary content (book files, page images, conversion outputs) MUST
  NOT be stored in `Rails.cache`; it lives in Active Storage. Cache the records and
  queries that describe it, not the bytes.
- **Tested both ways**: Every cached path MUST have tests proving (a) the cache-hit path
  avoids redundant queries and (b) a change to the underlying data invalidates the cache.

**Rationale**: A library catalog is read-heavy. Caching every model query keeps search and
browsing fast at scale, while callback-driven invalidation guarantees users never see a
stale catalog, library, or reading position after a change.

## Technology & Architecture Standards

- **Platform**: Ruby on Rails 8.1 with the Hotwire stack (Turbo + Stimulus), importmap,
  Propshaft, and PostgreSQL.
- **File storage**: Active Storage holds original uploads, covers, page thumbnails, and
  converted outputs (Principle VII).
- **Background processing**: Solid Queue runs conversion, metadata extraction, and cover
  generation jobs. Long-running file work MUST NOT run in the request cycle.
- **Reader rendering**: Document-rendering libraries are allowed only under the
  Principle I exception (importmap-pinned, Stimulus-wrapped, rendering only).
- **Testing tools**: RSpec (models, requests/controllers, jobs) with shoulda-matchers,
  FactoryBot, and FFaker; Capybara + Selenium for system specs; Playwright MCP for live
  task verification.
- **Delivery surfaces**: Responsive web, PWA, and Hotwire Native, all sharing the same
  Rails backend and Turbo-rendered views.
- **Styling**: Page-scoped CSS plus a `shared/` directory for typography, design tokens,
  and reader themes, governed by `DESIGN.md`.
- **CRUD UX**: `new`/`edit` flows (including admin book upload and editing) MUST use
  Turbo-rendered modals available app-wide.
- **Caching**: Model read queries MUST be served through `Rails.cache` (backed by Solid
  Cache) with version-aware keys and no other caching mechanism. Writes MUST invalidate the
  affected record and its associated records/collections via model callbacks
  (Principle IX).

## Development Workflow & Quality Gates

For every task, the following gates MUST pass before it is marked complete:

1. Implementation uses the Turbo/Hotwire strategy; any reader library follows the
   Principle I exception (Principle I).
2. RSpec backend specs (models, requests/controllers, jobs) and Capybara/Selenium system
   specs exist and pass (Principle II).
3. The task is verified working live via Playwright MCP (Principle II).
4. The change is verified on mobile (PWA / Hotwire Native) first, then desktop, including
   touch and keyboard reader control where relevant (Principle III).
5. Styling traces to `DESIGN.md`, reuses `shared/` tokens, and keeps the reading surface
   free of decoration (Principle IV).
6. Any reader-related change preserves automatic position persistence and resume, with
   tests and live verification (Principle V).
7. Reader changes are verified against reflowable, fixed-layout, and right-to-left
   fixtures (Principles II and VI).
8. Upload and conversion changes validate by content, leave originals untouched, run in
   background jobs, and validate outputs (Principle VII).
9. Every non-authentication endpoint requires sign-in, every admin-only endpoint has
   passing negative authorization specs, and personal data stays scoped to its owner
   (Principle VIII).
10. Model read queries are cached and every write invalidates the affected record and its
    associated records/collections, with tests for both the hit and invalidation paths
    (Principle IX).

Pull requests and reviews MUST confirm each applicable gate. Deviations require a
documented justification recorded in the plan's Complexity Tracking section.

## Governance

This constitution supersedes all other development practices. When guidance conflicts,
the constitution wins.

- **Amendments** MUST be proposed via pull request, documented with rationale, and
  approved by the project maintainer before taking effect. Material amendments MUST
  include a migration/update note for any affected templates or code.
- **Versioning** follows semantic versioning: MAJOR for backward-incompatible
  principle removals or redefinitions, MINOR for new principles or materially expanded
  guidance, PATCH for clarifications and non-semantic refinements.
- **Compliance review**: every PR MUST verify adherence to the applicable Quality Gates
  above. Unjustified violations block merge.
- **Runtime guidance**: agents and contributors use the active feature plan and
  `DESIGN.md` for day-to-day development guidance, within the bounds set here.

**Version**: 1.1.0 | **Ratified**: 2026-10-13 | **Last Amended**: 2026-10-13
