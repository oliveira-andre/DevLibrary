# Quickstart: Validating the Home Page, Book Page and Reader

**Feature**: [spec.md](spec.md) · **Data**: [data-model.md](data-model.md) ·
**Contracts**: [http.md](contracts/http.md), [reader-client.md](contracts/reader-client.md)

Use this after implementation to prove the feature works. It is a run guide, not code.

## Prerequisites

- Everything from the [001 quickstart](../001-core-data-model/quickstart.md).
- libvips (cover variants). It is already in the Dockerfile and installed locally.
- The `zip` CLI, used by `script/generate_spec_fixtures.rb`.
- Chrome for Selenium, and the Playwright MCP for live checks.

## 1. Setup

```sh
bin/rails db:migrate                       # reading settings columns + users.blocked_at
ruby script/generate_brand_assets.rb       # favicon, app icons, wordmarks, og-image (committed output)
ruby script/generate_spec_fixtures.rb      # now also writes the multi-page reader fixtures
bin/rails db:seed                          # now also seeds 120 catalog books, reviews and a collection
bin/dev
```

**Expected**:
- `db/schema.rb` shows `reader_page_animation`, `reader_theme` and `reader_text_size` on
  `users`, with their check constraints.
- `spec/fixtures/files/reader/` holds the multi-page PDF, EPUB, comic and right-to-left
  manga fixtures listed in research R14. The existing `sample.cbr` covers the CBR
  "can't be opened yet" state.
- The seeded `reader@devlibrary.test` has 12 books in their collection, 3 of them with
  saved positions. `reader2@devlibrary.test` has none.

## 2. Automated suite

```sh
bundle exec rspec spec/models spec/requests     # query objects, settings, every endpoint + negative auth
bundle exec rspec spec/system                   # every story, mobile then desktop
bundle exec rspec --tag caching                 # new cache paths: hit + invalidation
bundle exec rspec                               # everything, must be green
```

**Expected**: 0 failures. Every system example runs twice: "on mobile" (390×844) and
"on desktop" (1440×900).

## 3. What the system specs prove

| Spec file | Story | Key checks |
|---|---|---|
| `spec/system/home_spec.rb` | US1 | 50 newest + See more → 100 → 120 and gone. Publish between loads → no repeat. Empty catalog message |
| `spec/system/home_collection_spec.rb` | US2 | Collection row only when the library is non-empty, ordered by last read. Sideways scroll without vertical page movement. Tap → the reader URL for that book |
| `spec/system/search_spec.rb` | US6 | "cafe" finds "Café Noir". Category and sort keep the text. 80 results paged 50 + 30. No-results message |
| `spec/system/book_page_spec.rb` | US5 | Cover, title, description, rating summary. Post a review with an emoji → prepended, average updates, no reload. Validation keeps input. Edit in the modal. Delete. Admin deletes another person's review. Archived book has no form. Draft → not available |
| `spec/system/library_controls_spec.rb` | US7 | Add to collection → appears in the home row. Heart adds and favorites. Unheart keeps it in the collection. Remove, then add back → the reader still resumes |
| `spec/system/reader_spec.rb` | US3 | For each fixture (PDF, EPUB, comic, RTL manga): open → turn 3 pages → reopen in a fresh session → same position. CBR → the "can't be opened yet" message with a way back. Tap zones and keys follow direction. Direction switch persists. EPUB text size and theme keep the passage. Last page shows the end state |
| `spec/system/reader_persistence_spec.rb` | US3 | Turn, then navigate away at once → saved. Offline (Chrome network conditions) → turn → online → saved. Expire the session → turn → sign in → saved |
| `spec/system/sign_up_and_branding_spec.rb` | US8 | The logo is in the header (links home) and on sign-in, sign-up, forgot and reset password. Sign up "Ana" / " Ana@Example.COM " → home, signed in. Missing name keeps the typed values. Signed in → sign-in and sign-up redirect home |
| `spec/system/account_protection_spec.rb` | US8 | 6th attempt for one email → generic message even with the right password. Blocked account → generic message. Blocked mid-session → next click signs out with "Your account has been blocked." |
| `spec/system/page_animation_spec.rb` | US4 | Default animated (`data-reader-animation="slide"`, and the reader marks itself turning during the slide). Switch off → instant, persists to a second session. RTL mirrors. Three quick turns land three pages ahead. A reduced-motion browser is instant |

## 4. Live verification (Playwright MCP)

Run every step at **mobile 390×844 first**, then repeat at **desktop 1440×900**.

1. Sign in as `reader@devlibrary.test` / `password123`. **Expected**: home shows "Your
   collection" above "Newest books" (50 cards). The collection has 12 books: the three with
   saved positions first, most recently read first (Sample Manga, Café Noir, The Sample
   PDF), each with a progress bar.
2. Swipe the collection row (mobile) or scroll it with the trackpad and arrow buttons
   (desktop). **Expected**: it scrolls sideways and the page does not scroll.
3. Tap "See more" twice. **Expected**: 100, then 120 cards. "See more" is gone. No card
   repeats.
4. Search "cafe". **Expected**: "Café Noir" appears. Pick a category and a sort.
   **Expected**: the text stays in the box and the results change.
5. Open "Café Noir". **Expected**: cover, title, description with emoji, rating summary and
   reviews. Post 4 stars + "Loved it 🤩". **Expected**: it appears at the top and the
   average and count update without a reload. Edit it to 2 stars in the modal, then
   delete it.
6. Tap Read. Turn 3 pages (tap the right edge on mobile, the arrow key on desktop) and
   close the tab. Reopen from the collection row. **Expected**: same page.
7. Open the seeded manga. **Expected**: tapping the left edge goes forward. Switch the
   direction to left-to-right, reload, and check the choice is kept.
8. Open Reading settings from the account menu and switch the animation off. Turn a page.
   **Expected**: instant. Sign in as the same user in a second browser context. **Expected**:
   instant there too. Switch it back on.
9. Sign in as `reader2@devlibrary.test`. **Expected**: no "Your collection" row.
10. Sign out. **Expected**: the sign-in page shows the large wordmark, and the tab shows the
    book-stack favicon. Follow "Create an account" and sign up as a new person.
    **Expected**: the home page, signed in, with no collection row.
11. In the console, `User.find_by(email_address: "reader2@devlibrary.test").block!` while
    that person is signed in a second context. Click anything. **Expected**: back on
    sign-in with "Your account has been blocked."
12. **Previews**, once the amendment is ratified. Signed out, run
    `curl -s http://localhost:3000/books/<public_id> | grep og:` for a published book.
    **Expected**: title, "by …" and the preview image only. A draft's id gives
    `302 /session/new`. Through a tunnel (e.g. `cloudflared`), paste a book link into
    WhatsApp, Slack, iMessage and Discord. **Expected**: the cover, title and author card.
13. Screenshot each screen at both sizes into `.playwright-mcp/` for the record.

## 5. Performance checks

```sh
bin/rails runner script/benchmark_search.rb   # existing: search p95 < 1 s at 10k books
bin/rails runner script/benchmark_home.rb     # new: recent batch + keyset See more p95 < 1 s at 10k books (SC-001)
```

**SC-005 (large PDF)**: `ruby script/generate_large_pdf.rb tmp/large.pdf` writes a
~500 MB image-heavy PDF. Attach it to a seeded book from the console. In Playwright,
check the network panel. **Expected**: the reader shows the saved page within 5 s, using
`Range` requests, and the whole file is never downloaded.
