# Contract: HTTP Endpoints and Turbo Targets

**Covers**: FR-001–FR-020, FR-022–FR-026, FR-032–FR-034, FR-038–FR-054 · **Data**: [data-model.md](../data-model.md)
· **Reader client**: [reader-client.md](reader-client.md)

Every endpoint requires a signed-in session (constitution Principle VIII). The exceptions
are the authentication flows (sign-in, sign-up, password reset) and, **once the Principle
VIII amendment is ratified**, the two link-preview responses (research R17). Anonymous HTML
requests get `302 → /session/new` and return to the original URL after sign-in (existing
`Authentication` concern).

**New in this feature**:
- Anonymous **JSON** requests get `401 Unauthorized` instead of a redirect, so the
  reader's position outbox can tell "signed out" from "saved" (research R5).
- A session whose user is **blocked** is destroyed on its next request. HTML requests are
  redirected to `/session/new` with the alert "Your account has been blocked." JSON
  requests get `403 Forbidden` (research R18, FR-052).

`:book_id` / `:id` on book routes is the book's `public_id` (001 R7). Book lookups go
through `Book.find_visible_cached!`. Drafts, deleted books and archived books the person
does not keep all give **404** with the "This book isn't available" page (FR-019).

## Routes

```ruby
resource :session                                   # existing (new, create, destroy)
resources :passwords, param: :token                 # existing
resource :registration, only: %i[new create]        # sign-up (R15)

root "home#show"
get "home", to: "home#show", as: :home              # kept: after_authentication_url → home_url
resources :recent_books, only: :index               # "See more" on the home page

resources :books, only: %i[index show] do           # index = search results
  scope module: :books do
    resource :reader,            only: :show, path: "read"
    resource :file,              only: :show
    resource :reading_position,  only: :update
    resource :reading_direction, only: :update
    resource :library_entry,     only: %i[create destroy]
    resource :favorite,          only: %i[create destroy]
    resources :reviews,          only: %i[index create]
    resource :preview_image,     only: :show        # public, published only (R17)
  end
end
resources :reviews, only: %i[edit update destroy]   # edit renders in the app-wide modal
resource :reading_settings, only: %i[edit update]
get "manifest" => "rails/pwa#manifest", as: :pwa_manifest   # enabled (research R11)
```

## Endpoints

| Method & path | Controller#action | Formats | Success | Failure |
|---|---|---|---|---|
| `GET /session/new` | `sessions#new` | html, `auth` layout | 200: logo, sign-in form, "Create an account" and "Forgot password?" links, branded preview meta | signed in → `302 → /` |
| `POST /session` | `sessions#create` | html | `302 → after_authentication_url` | **every** failure gives `302 → /session/new` with the alert "Try another email address or password.": unknown email, wrong password, locked, blocked, IP bucket (> 10 per 3 min) and email bucket (> 5 per 15 min per normalized email). Byte-identical responses |
| `GET /registration/new` | `registrations#new` | html, `auth` layout | 200: logo, form (name, email, password, confirmation), link back to sign-in | signed in → `302 → /` |
| `POST /registration` | `registrations#create` | html | creates a **reader** with `save(context: [:create, :sign_up])`, starts a session, `302 → after_authentication_url` | 422: form with errors, name and email kept, password fields empty. > 10 per 3 min per IP → `302 → /registration/new`, alert "Try again later." `user[role]` is ignored |
| `GET /passwords/new`, `GET /passwords/:token/edit` | `passwords#new`, `#edit` | html, `auth` layout | existing behaviour, now in the branded layout | existing |
| `GET /` and `GET /home` | `home#show` | html | 200: search box, `#collection` row (only if the library has entries), `#recent_books` grid of 50, `#recent_books_more` | — |
| `GET /recent_books?before=:cursor` | `recent_books#index` | turbo_stream, html | stream: `append "recent_books"` (50 cards) + `replace "recent_books_more"` (next control, or nothing on the last page). HTML: a plain page of that batch | bad cursor → first batch |
| `GET /books?q=&category=&sort=&page=` | `books#index` | html, turbo_stream | HTML (page 1): search box filled in, category and sort dropdowns, `#search_results` + `#search_results_more`. Stream (page > 1): `append "search_results"` + `replace "search_results_more"` | unknown category or sort → ignored (001 defaults). No match → "No books found" + link home |
| `GET /books/:id` | `books#show` | html | 200: cover, title, authors, categories, description, Read action, `#library_controls`, `#rating_summary`, `#review_form` (or own review panel), `#reviews` (20) + `#reviews_more` | 404 not available |
| `GET /books/:id` **signed out** | `books#show` → `books/previews#show` | html, `preview` layout | published book: **200** with og/twitter meta (title, "by " + authors, preview image or `/og-image.png`, `og:type` book), a body with only cover, title, authors and "Sign in to read", `<meta http-equiv="refresh" content="0;url=/session/new">`, and the return-to set to this book | any other book (draft, archived, deleted, unknown): `302 → /session/new` like every protected page |
| `GET /books/:book_id/preview_image` | `books/preview_images#show` | image/jpeg | **public**. Published book with a cover: the `:preview` variant, `Cache-Control: public, max-age=300` | 404 for anything else. > 60 per minute per IP → 429 |
| `GET /books/:book_id/reviews?page=` | `books/reviews#index` | turbo_stream | `append "reviews"` + `replace "reviews_more"` | 404 |
| `POST /books/:book_id/reviews` | `books/reviews#create` | turbo_stream | 200 stream: `prepend "reviews"`, `replace "review_form"` with the own-review panel, `replace "rating_summary"` | 422 stream: `replace "review_form"` with errors and the person's input kept. Already reviewed / not published → 422 with the model message |
| `GET /reviews/:id/edit` | `reviews#edit` | html (frame `modal`) | 200: the edit form inside `turbo_frame_tag "modal"` | 404 unless `Current.user` wrote it |
| `PATCH /reviews/:id` | `reviews#update` | turbo_stream | `replace dom_id(review)`, `replace "review_form"` (own panel), `replace "rating_summary"`, `update "modal"` (empty, which closes it) | 422: `replace "modal_body"` with errors. 404 unless author |
| `DELETE /reviews/:id` | `reviews#destroy` | turbo_stream | `remove dom_id(review)`, `replace "rating_summary"`. If the author deleted it: `replace "review_form"` with an empty form | 404 unless author or admin |
| `POST /books/:book_id/library_entry` | `books/library_entries#create` | turbo_stream | `replace "library_controls"` (in collection) | 422 if the book is not published (001 rule) |
| `DELETE /books/:book_id/library_entry` | `books/library_entries#destroy` | turbo_stream | `replace "library_controls"`. Position, notes and bookmarks are kept | — |
| `POST /books/:book_id/favorite` | `books/favorites#create` | turbo_stream | `replace "library_controls"` (heart filled, in collection) | 422 if not published |
| `DELETE /books/:book_id/favorite` | `books/favorites#destroy` | turbo_stream | `replace "library_controls"` (heart empty, still in collection) | — |
| `GET /books/:book_id/read` | `books/readers#show` | html, `reader` layout | 200: the reader shell with the data attributes in [reader-client.md](reader-client.md) | 404. A book with no file gets the "can't be opened" state, not a blank page |
| `GET /books/:book_id/file` | `books/files#show` | any | Streams the original file, authorized by the session cookie on every request. Honors a single `Range` (`206` with `Content-Range`), always sends `Accept-Ranges: bytes` and `Content-Length`, no `Content-Encoding`, `Cache-Control: private, no-store` (research R6) | 404. `416` for an unsatisfiable range |
| `PATCH /books/:book_id/reading_position` | `books/reading_positions#update` | json | `204 No Content`. Body: `{ location, progress, read_at }`. Calls `ReadingPosition.record!` (newest wins) | 401 signed out. 403 blocked (nothing saved). 404 not visible. 422 `{ errors: [...] }` for invalid progress |
| `PATCH /books/:book_id/reading_direction` | `books/reading_directions#update` | turbo_stream | `replace "reader_preferences"` with the new effective direction. Blank `direction` clears the override | 422 invalid value |
| `GET /reading_settings/edit` | `reading_settings#edit` | html (frame `modal` or `reading_settings`) | 200: the settings form (animation switch, theme, text size) | — |
| `PATCH /reading_settings` | `reading_settings#update` | turbo_stream, html | stream: `replace "reading_settings_form"` (shows "Saved") and `replace "reader_preferences"` (ignored when not on the reader). HTML: redirect back | 422: form with errors |

## Turbo targets (stable DOM ids)

| Id | Lives on | Replaced by |
|---|---|---|
| `modal` | layout (`<turbo-frame>` inside a `<dialog>`) | any modal response. An empty update closes it |
| `recent_books`, `recent_books_more` | home | `recent_books#index` |
| `search_results`, `search_results_more` | search results | `books#index` (stream) |
| `collection` | home | — (rendered on page load) |
| `library_controls` | book page | library entry and favorite actions |
| `rating_summary`, `review_form`, `reviews`, `reviews_more` | book page | review actions |
| `dom_id(book)` (e.g. `book_42`) | every card | Turbo `append` replaces a duplicate id in place (FR-011) |
| `dom_id(review)` | each review | review update and destroy |
| `reader_preferences` | reader | direction and settings updates |
| `reading_settings_form` | settings modal and reader panel | settings update |

## Authorization rules (enforced in controllers, Principle VIII)

- Book-scoped actions resolve the book through `Book.find_visible_cached!(id, user: Current.user)`.
- `reviews#edit` and `#update` load through `Current.user.reviews.find(params[:id])`, so
  another person's review is 404, never 403. This reveals nothing.
- `reviews#destroy` loads `Current.user.admin? ? Review.find(id) : Current.user.reviews.find(id)`.
- Library, favorite, reading position, direction and settings always act on
  `Current.user` (and its library). No user or library id is ever read from params.
- Strong params: `review: [:rating, :content]`. `reading_settings: [:reader_page_animation,
  :reader_theme, :reader_text_size]`. Position: `location`, `progress`, `read_at` only.

## Layouts and head tags

| Layout | Used by | Head |
|---|---|---|
| `application` | every signed-in page | nav bar with the wordmark on the left (links home) and the account menu. Favicon set, apple-touch icon, manifest, branded `link_preview` meta |
| `auth` | sessions, registrations, passwords | centered card with the large wordmark. Same icons and branded meta. No nav |
| `reader` | `books/readers#show` | icons only. No logo or decoration (FR-045) |
| `preview` | signed-out published book preview | book-specific og/twitter meta. Minimal body |

## Required tests

- **Account protection request specs** (`sessions_spec`, `registrations_spec`, plus a
  blocked-session spec):
  - identical responses for all six sign-in failure kinds;
  - the 6th attempt per email within 15 minutes is refused from rotating `REMOTE_ADDR`s;
  - sign-up creates a reader even with `user[role]=admin`, and keeps name and email on 422;
  - signed in → `/session/new` and `/registration/new` redirect home;
  - a blocked user's HTML request → sign-in with the alert, and the session row is gone;
  - a blocked user's JSON position save → 403 with no position written;
  - the lock email is enqueued exactly once per lockout and never for blocked users.
- **Preview request specs**:
  - signed-out published book → 200 with exactly title, authors and image in
    og/twitter meta. The body has no description, rating or review text;
  - draft, archived, deleted and unknown → 302 sign-in;
  - preview image 200 for published, 404 after unpublishing;
  - a signed-in request to `/books/:id` still renders the full book page.
- **Request specs, one file per controller**:
  - each success row and each failure row above;
  - anonymous → `302` sign-in (HTML) or `401` (JSON position);
  - someone else's review edit, update and destroy → 404;
  - an admin destroying any review → success;
  - a draft book on every book-scoped route → 404;
  - duplicate `See more` ids are allowed (the client dedupes);
  - a bad cursor gives the first batch;
  - the position endpoint keeps the newest write, given two out-of-order PATCHes.
- **System specs**: see [quickstart.md](../quickstart.md) §3. Mobile first, then desktop.
