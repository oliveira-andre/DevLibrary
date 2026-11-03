# Contract: Reader Client

**Covers**: FR-021–FR-035 · **Research**: R1, R4, R5, R12 · **HTTP**: [http.md](http.md)

How the server-rendered reader shell (`GET /books/:book_id/read`) hands off to the browser,
and what the browser promises in return. Engines render book content only. Every piece of
application state (position, direction, settings) goes through the Rails endpoints below
(constitution Principle I exception).

## 1. Shell rendered by the server

```html
<main id="reader" data-controller="reader"
      data-reader-format-value="pdf|epub|cbz|cbr"
      data-reader-file-url-value="/books/:public_id/file"
      data-reader-position-url-value="/books/:public_id/reading_position"
      data-reader-book-id-value=":public_id"
      data-reader-user-id-value=":user_id"
      data-reader-start-location-value="12 | epubcfi(...) | (empty)"
      data-reader-start-progress-value="4.17"
      data-reader-start-read-at-value="2026-10-20T13:05:00Z | (empty)"
      data-reader-sign-in-url-value="/session/new"
      data-reader-state="loading"
      data-reader-animation="slide|none"
      data-reader-location="" data-reader-progress="">
  <div id="reader_preferences" data-controller="reader-preferences"
       data-reader-preferences-animation-value="true"
       data-reader-preferences-theme-value="light|sepia|dark"
       data-reader-preferences-text-size-value="100"
       data-reader-preferences-direction-value="ltr|rtl"
       data-reader-preferences-direction-override-value="ltr|rtl|(empty)"></div>
  … toolbar (back, title, progress, Aa settings panel, direction switch) …
  … reading surface (theme tokens only: no decoration, FR-030) …
</main>
```

- `#reader_preferences` is replaced by the Turbo Streams from `reading_settings#update` and
  `reading_directions#update`. On `connect()` it dispatches
  `reader-preferences:changed` with its values, and `reader` applies them. Settings and
  direction therefore change through server responses, never through client-held state.
- The `data-reader-*` state attributes are the test hooks (§7).

## 2. Engine adapter interface

`reader` loads exactly one adapter with `import()`, chosen by format:

| Format | Adapter module | Source |
|---|---|---|
| `epub` | `reader/engines/reflowable` | foliate-js `view.js` (pinned, `preload: false`) |
| `pdf` | `reader/engines/fixed_layout` | `reader/sources/pdf_source` → pdfjs-dist |
| `cbz` | `reader/engines/fixed_layout` | `reader/sources/cbz_source` → zip.js `HttpRangeReader` |
| `cbr` | none | the shell renders the "can't be opened yet" state server-side (FR-024) |

Every adapter exports `async open(container, options)` and returns an object with:

| Member | Contract |
|---|---|
| `next()` / `prev()` | Logical forward or back, honoring the effective direction. They return `false` at the end or the beginning instead of moving (FR-029) |
| `goTo(location)` | Jumps to a stored locator. An unknown locator falls back as in §4 |
| `setDirection("ltr"\|"rtl")` | Re-maps order and gestures without losing the current page |
| `setAnimation(boolean)` | `true` = slide, `false` = instant. Callers already folded in reduced motion (§5) |
| `setTheme(name)` / `setTextSize(pct)` | Reflowable: restyle and keep the current CFI in view. Fixed-layout: theme sets the surround only, text size is a no-op |
| `zoom` *(fixed-layout only)* | `in()`, `out()`, `fit()` and `isZoomed`. Page turns pause while zoomed (FR-028) |
| `destroy()` | Releases canvases, object URLs, iframes and listeners |
| event `relocate` | `CustomEvent` with detail `{ location, progress, atStart, atEnd, label }` after every settled move |

`options`: `{ fileUrl, startLocation, startProgress, direction, animation, theme, textSize }`.

Fixed-layout **sources** expose `pageCount`, `pageSize(index)` and
`async render(index, { width, height, scale })`, which returns a `<canvas>` or `<img>`. The
pager keeps the previous, current and next page rendered (R4).

## 3. Locators and progress

| Format | `location` | `progress` (0–100) | `label` |
|---|---|---|---|
| PDF, CBZ | 1-based page number as a string, `"12"` | `(page − 1) / (pageCount − 1) × 100` (100 for a single page) | `"Page 12 of 240"` |
| EPUB | CFI from foliate's `relocate` | `fraction × 100` | chapter title, plus `"42%"` |

## 4. Start position (FR-022)

1. Start from the server's `start-location`, `start-progress` and `start-read-at`.
2. If the outbox (§6) holds an entry with a later `read_at`, start there instead.
3. Fixed-layout: clamp the page to `1..pageCount`. If it is unparsable, use 1.
4. EPUB: `goTo(cfi)`. If that rejects, `goToFraction(progress / 100)`. If there is no
   progress either, start at the beginning.

## 5. Input and animation

| Input | Effect |
|---|---|
| Tap the outer 30% on the left or right | previous or next, mapped through the direction (in RTL, left = next) |
| Tap the middle | toggle the toolbar |
| Swipe ≥ 40 px within 30° of horizontal | next or previous by visual direction. The slide follows the finger (fixed-layout) |
| ArrowRight / ArrowLeft | visual: in LTR right = next, in RTL left = next |
| PageDown / Space · PageUp / Shift+Space | logical next · previous |
| Pinch, double-tap, Ctrl/⌘+wheel, +/− | zoom (fixed-layout). While zoomed, a drag pans |

**Effective animation** = `preferences.animation && !matchMedia("(prefers-reduced-motion:
reduce)").matches`, re-evaluated when either changes. It is written to
`data-reader-animation`.

- **Fixed-layout slide**: a 250 ms ease-out `translateX` of the page track. A new input
  during a slide calls `finish()` first, then performs the next move, so moves are never
  dropped or left half-done.
- **Reflowable**: foliate's `animated` attribute, present only while the effective
  animation is on.
- **Instant**: no animation is created, and the page swaps within one frame (SC-004).
- `data-reader-turning` is present only while a slide runs.

## 6. Position outbox (FR-023)

- **Key**: `devlibrary:reading-position:<user_id>:<public_id>` in `localStorage`. Every
  access is wrapped in `try/catch`. Without storage, the outbox lives in memory only.
- **Entry**: `{ location, progress, read_at }`. `read_at` is `new Date().toISOString()` at
  the moment of `relocate`.
- **Request**: `PATCH position-url`, with
  - headers: `Content-Type: application/json`, `Accept: application/json`,
    `X-CSRF-Token: <meta csrf-token>`;
  - body: the entry;
  - `keepalive: true`.

  At most one request is in flight. A newer entry replaces the pending one.
- **Flush triggers**: after `relocate`; `visibilitychange` → hidden; `pagehide`;
  `disconnect()` (Turbo navigation); `online`; the retry timer.

| Response | Client action |
|---|---|
| `204` | Clear the entry if its `read_at` is unchanged |
| network error / `5xx` | Keep the entry. Retry after 1 s, doubling to a 30 s cap |
| `401` | Keep the entry. Show the "Sign in again to keep saving your place" banner, linking to `sign-in-url` (which returns to the reader). Stop retrying until reconnect |
| `403` | The account is blocked. Drop the entry, stop retrying, and switch to the `blocked` state (FR-052) |
| `404` | Drop the entry. Show the "not available" state |
| `422` | Drop the entry (a bad locator must not loop forever) |

The server's newest-wins rule (001 `ReadingPosition.record!`) makes duplicates and
out-of-order arrivals harmless.

## 7. States and test hooks

| `data-reader-state` | Shown |
|---|---|
| `loading` | spinner over the surface (large files: until the start page is rendered) |
| `ready` | the page |
| `error` | "This book can't be opened" with a back link (unreadable or corrupt file) |
| `unsupported` | CBR: "This comic can't be opened in the reader yet" with a back link |
| `unavailable` | after a `404`: "This book isn't available" |
| `blocked` | after a `403`: "Your account has been blocked." with a link to sign-in |

After each settled move, `data-reader-location` and `data-reader-progress` mirror the last
`relocate`. System specs assert on these, not on pixels.

## 8. Vendored modules (importmap)

| Pin | Source | Notes |
|---|---|---|
| `foliate-js/view` | `/vendor/foliate-js/78914ae/view.js` | `public/`. Relative imports and `import.meta.url` must keep working |
| `pdfjs-dist` | `/vendor/pdfjs-dist/6.4.299/build/pdf.min.mjs` | `public/`. `workerSrc` = `import.meta.resolve("pdfjs-dist/worker")`. `cMapUrl`, `standardFontDataUrl`, `wasmUrl` and `iccUrl` all under the same versioned folder |
| `pdfjs-dist/worker` | `/vendor/pdfjs-dist/6.4.299/build/pdf.worker.min.mjs` | `preload: false` |
| `@zip.js/zip.js` | `vendor/javascript/@zip.js--zip.js@2.23.0.js` (root `index.min.js`) | self-contained. `configure({ useWebWorkers: false })` |
| `emoji-picker-element` | `/vendor/emoji-picker-element/1.29.1/index.js` | `public/`. Data JSON self-hosted beside it (R8) |
| `reader/*` | `pin_all_from "app/javascript/reader", under: "reader"` | app code. Adapters are loaded with `import()` |

All engine pins use `preload: false`, so only the reader page downloads them, and only for
the book's format.
