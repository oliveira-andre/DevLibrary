# Feature Specification: Home Page, Book Page and Reader

**Feature Branch**: `main` (no feature branch created)

**Created**: 2026-10-20

**Status**: Draft

**Input**: User description: "lets start building the home page, the home will show the most recent books, for the users with books on collection it should show "your collection" first that also when opening the book we should start reading as i always said open on the page using the selected page by the user account, also i wanna the animation of changing page, this setting should be saved on user config, but we must be able to switch the animation so it instantly go to next when we click we must be able to scroll on the books using for the collection but the list of most recent ones it should show the first 50 books only if wanna more should have a "see more" then always loads more 50, we should have on top of the page a search centered, to search for books. when seeing the books i already pasted the result we should have the cape, title, description, then reviews and ratings made by users also a form so other users can do it"

## Scope

This is the first screen feature. It builds on the data and rules from
[001-core-data-model](../001-core-data-model/spec.md) and delivers:

- the **home page**: a centered search box, the person's collection (when they have one)
  and the newest books, 50 at a time;
- **search results** for the home search box, with the category and sort dropdowns
  planned in 001;
- the **book page**: cover, title, description, ratings and reviews, and a review form;
- the **reader**: opens at the person's saved page, saves every page turn, and turns
  pages with an animation the person can switch off;
- **reading settings** saved on the person's account;
- **sign-up**, plus one branded design shared by sign-up, sign-in, forgot password and
  reset password.

It also adds the app's shared look (navigation bar, buttons, cards, modal) from
`DESIGN.md`, and the DevLibrary logos from `app/assets/images` in the header, on the
sign-in pages and as the favicon and app icon, because no screen has them yet. Links
pasted into other apps show a preview: the DevLibrary brand, or a published book's cover,
title and author.

**Out of scope** (each gets its own spec later): account settings other than reading
settings, the full library page with shelves, reading notes, bookmarks, download, convert,
the share button, and admin catalog management. Books for this feature come from the existing seed
data and console.

## Clarifications

### Session 2026-10-20

- Q: Should this feature also build a sign-up page, since none exists yet? → A: Yes. Build
  a simple sign-up page now (name, email, password, confirm password), sharing the branded
  design with sign-in, forgot password and reset password.
- Q: When someone pastes a DevLibrary link into WhatsApp, Slack, iMessage or Discord,
  what should the preview card show? → A: Book links show that book's cover, title and
  author. Other links show the branded DevLibrary preview. This requires a constitution
  amendment allowing public previews of published books.
- Q: Should a new account have to confirm its email address before it can use the app?
  → A: No. Sign-up signs the person in immediately. Account security matches DevCine and
  Spotsby: a per-email sign-in rate limit on top of the per-IP one (generic message when
  throttled), accounts that can be blocked, an email with a reset link when an account
  locks, and signed-in people redirected away from sign-in and sign-up.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse the newest books (Priority: P1)

A signed-in person opens the app and sees the newest books first: each one shows its
cover with the title below. The first 50 appear right away. A "See more" button at the end
loads the next 50, and keeps doing so until there are no more books.

**Why this priority**: It is the first thing everyone sees, and the way into every book.

**Independent Test**: Seed a catalog of 120 published books and browse the home page,
loading more until the list ends.

**Acceptance Scenarios**:

1. **Given** 120 published books, **When** a person opens the home page, **Then** they see
   the 50 most recently published, newest first, followed by "See more".
2. **Given** the first 50 are shown, **When** the person taps "See more", **Then** the next
   50 appear below the first ones without leaving the page or losing their scroll place.
3. **Given** 100 books are shown, **When** the person taps "See more" again, **Then** the
   last 20 appear and "See more" disappears.
4. **Given** exactly 50 published books, **When** the home page opens, **Then** all 50 show
   and there is no "See more".
5. **Given** draft and archived books exist, **When** the home page opens, **Then** none of
   them appear in the newest list.
6. **Given** a book is published after the person opened the home page, **When** they tap
   "See more", **Then** no book is shown twice and no book is skipped.
7. **Given** no published books, **When** the home page opens, **Then** a friendly empty
   message is shown instead of the list.
8. **Given** a signed-out visitor, **When** they open the home page, **Then** they are sent
   to sign-in and land back on the home page afterwards.

---

### User Story 2 - Your collection first, one tap back into reading (Priority: P1)

A person who keeps books in their collection sees a "Your collection" row above the newest
books. It shows each cover with the title below and how far they have read, most recently
read first. The row scrolls sideways (swipe on a phone). Tapping a book opens it straight
in the reader at the page where they stopped.

**Why this priority**: Getting back to the book you are reading is the product's defining
promise (constitution Principle V).

**Independent Test**: Give one account a collection with reading positions and another
account an empty collection, then open the home page as each.

**Acceptance Scenarios**:

1. **Given** a person with 3 books in their collection, **When** they open the home page,
   **Then** "Your collection" appears above the newest books with those 3 books.
2. **Given** a person with an empty collection, **When** they open the home page, **Then**
   no "Your collection" row is shown.
3. **Given** a person read book A yesterday and book B an hour ago, **When** they open the
   home page, **Then** B comes before A in the row.
4. **Given** a collection of 30 books on a phone, **When** the person swipes the row,
   **Then** it scrolls sideways through all 30 without moving the page up or down.
5. **Given** the person stopped on page 42 of a book in their collection, **When** they tap
   it, **Then** the reader opens directly on page 42.
6. **Given** a book in the collection was archived by an admin, **When** the person opens
   the home page, **Then** it still appears in their collection and opens in the reader.

---

### User Story 3 - Read and resume exactly where you stopped (Priority: P1)

Any book a person can see opens in the reader with one tap: from their collection, from a
book card, or from the book page. The reader opens at the page saved for that person's
account, on any device. Every page turn is saved automatically. Pages turn by tapping or
swiping on a phone and with the arrow keys on a computer, in the book's reading direction.

**Why this priority**: Reading is the core purpose of the app. Without it, the home page
and collection have nowhere to lead.

**Independent Test**: Open a multi-page PDF, EPUB, comic and right-to-left manga, turn
pages, leave, and reopen each one on a different browser session.

**Acceptance Scenarios**:

1. **Given** a person was on page 42 of a PDF on their phone, **When** they open the same
   book on a computer, **Then** the reader opens on page 42.
2. **Given** a person has never opened a book, **When** they open it, **Then** the reader
   starts at the beginning.
3. **Given** a person turns to page 10 and immediately closes the tab, **When** they reopen
   the book, **Then** it opens on page 10.
4. **Given** the connection drops while a person reads from page 10 to page 14, **When** the
   connection returns, **Then** page 14 is saved, without the person doing anything.
5. **Given** a right-to-left manga, **When** the person taps the left side of the page or
   swipes right, **Then** the reader moves to the next page.
6. **Given** a manga that reads right-to-left, **When** the person switches the direction to
   left-to-right in the reader, **Then** the choice applies only to them and only to that
   book, and is restored the next time they open it.
7. **Given** a reflowable EPUB, **When** the person makes the text larger or switches to the
   dark theme, **Then** the text reflows and the reader stays on the same passage.
8. **Given** a comic page on a phone, **When** the person pinches to zoom, **Then** the page
   enlarges and can be panned. Page turns resume once zoom is back to fit.
9. **Given** a book that is not in the person's collection, **When** they read it, **Then**
   their position is saved and the book is not added to their collection.
10. **Given** the person is on the last page, **When** they try to go to the next page,
    **Then** the reader stays there and shows that they have reached the end.

---

### User Story 4 - Page-turn animation the person can switch off (Priority: P2)

Turning a page plays a short animation in the reading direction. A person who prefers
instant page changes switches the animation off in reading settings. The setting is saved
on their account, so it applies to every book on every device.

**Why this priority**: Explicitly requested and part of the reading feel, but reading works
without it.

**Independent Test**: Turn pages with the setting on and off on two different sessions of
the same account.

**Acceptance Scenarios**:

1. **Given** a new account, **When** the person turns a page, **Then** the page change is
   animated.
2. **Given** the person switches the animation off, **When** they tap to turn a page,
   **Then** the next page appears at once, with no transition.
3. **Given** the animation was switched off on the phone, **When** the person reads on a
   computer, **Then** pages turn instantly there too.
4. **Given** a right-to-left book with animation on, **When** the person turns a page,
   **Then** the animation moves in the opposite direction to a left-to-right book.
5. **Given** the animation is on, **When** the person taps three times quickly, **Then** the
   reader lands three pages ahead and the animation never leaves a page half-turned.
6. **Given** the person's device asks apps to reduce motion, **When** they turn a page,
   **Then** it changes instantly, even with the animation setting on.

---

### User Story 5 - Book page with ratings and reviews (Priority: P2)

Tapping a book card opens the book's page: its cover, title, authors, categories and
description, then its average rating, the number of reviews and the reviews other people
wrote. A signed-in person who has not reviewed the book yet sees a form to give 1 to 5
stars and write a review with rich text and emoji.

**Why this priority**: Helps people choose what to read. The home page and reader work
without it.

**Independent Test**: Open a published book with existing reviews, post a review, edit it
and delete it, and check the average and count each time.

**Acceptance Scenarios**:

1. **Given** a published book, **When** a person opens its page, **Then** they see the
   cover, title, authors, categories, description, a "Read" button, the average rating and
   the review count, followed by its reviews, newest first.
2. **Given** a book with no cover, **When** its page or card is shown, **Then** a
   placeholder with the title is shown instead.
3. **Given** a person who has not reviewed the book, **When** they pick 4 stars, write
   "Loved it 🤩" and submit, **Then** the review appears at the top of the list under
   their name and the average and count update, without reloading the page.
4. **Given** a person submits a review without stars or without text, **When** it is
   submitted, **Then** it is rejected with a message saying what is missing, and what they
   wrote is kept.
5. **Given** a person has already reviewed the book, **When** they open its page, **Then**
   the form is replaced by their own review with options to edit or delete it.
6. **Given** a person edits their review from 4 to 2 stars, **When** they save, **Then**
   the review and the average update in place.
7. **Given** an admin, **When** they view any review, **Then** they can delete it.
8. **Given** a book with 45 reviews, **When** the page opens, **Then** 20 are shown with a
   "See more reviews" button that loads the next 20.
9. **Given** an archived book in the person's collection, **When** they open its page,
   **Then** they see its reviews but no review form.
10. **Given** a draft or deleted book, **When** a reader opens its address, **Then** they
    are told the book is not available.

---

### User Story 6 - Search from the home page (Priority: P2)

A search box sits centered at the top of the home page. Typing a title or author and
submitting it shows the matching books in the same card layout, with a category dropdown
and a sort dropdown to narrow and order them.

**Why this priority**: Browsing covers small catalogs. Search matters as the catalog grows.

**Independent Test**: Seed books with accented titles and several categories, then search,
filter and sort.

**Acceptance Scenarios**:

1. **Given** a published book "Café Noir", **When** the person searches "cafe", **Then** it
   appears in the results.
2. **Given** search results, **When** the person picks the "Fantasy" category, **Then** only
   Fantasy books remain, and the search text is kept.
3. **Given** search results, **When** the person picks "Top rated", **Then** the results are
   ordered by average rating.
4. **Given** 80 matching books, **When** results open, **Then** 50 show with "See more",
   which loads the remaining 30.
5. **Given** a search that matches nothing, **When** results open, **Then** a "no books
   found" message is shown with a way back to the home page.
6. **Given** the person submits an empty search, **When** results open, **Then** they show
   all books, newest first.

---

### User Story 7 - Keep and favorite a book from its page (Priority: P3)

From the book page a person adds the book to their collection, removes it, or taps the
heart to mark it as a favorite.

**Why this priority**: Without a way to add books, "Your collection" stays empty. The full
library page comes later.

**Independent Test**: Add, favorite, unfavorite and remove a book from its page, checking
the home page collection row after each step.

**Acceptance Scenarios**:

1. **Given** a book not in the collection, **When** the person taps "Add to collection",
   **Then** the button shows it is in the collection and the book appears in "Your
   collection" on the home page.
2. **Given** a book not in the collection, **When** the person taps the heart, **Then** the
   book is added to the collection and marked as a favorite.
3. **Given** a favorite, **When** the person taps the heart again, **Then** it is no longer
   a favorite but stays in the collection.
4. **Given** a book in the collection with a saved position, **When** the person removes it
   and adds it back later, **Then** the reader still opens at the saved page.

---

### User Story 8 - Create an account and sign in under the DevLibrary brand (Priority: P2)

A new person opens the app, sees the DevLibrary logo on the sign-in page, follows "Create
an account", and signs up with their name, email and a password. They land on the home
page signed in. Sign-in, sign-up, forgot password and reset password all share the same
branded design.

**Why this priority**: Without sign-up, nobody can reach the home page unless an account
is made for them in the console. The account rules already exist in 001.

**Independent Test**: Sign up a new account, sign out, sign back in, and request a
password reset, checking the logo and design on each page.

**Acceptance Scenarios**:

1. **Given** a signed-out visitor, **When** they open the app, **Then** the sign-in page
   shows the DevLibrary logo with its name and a "Create an account" link.
2. **Given** the sign-up page, **When** someone enters the name "Ana", the email
   " Ana@Example.COM " and a matching 8+ character password, **Then** the account is
   created as a reader with the email "ana@example.com", they are signed in, and they land
   on the home page.
3. **Given** the sign-up page, **When** someone submits without a name, **Then** it is
   rejected with "Name can't be blank", and the name and email they typed are kept.
4. **Given** an account for "ana@example.com", **When** someone signs up with
   "ANA@example.com", **Then** it is rejected because the email is already in use.
5. **Given** a password shorter than 8 characters or a confirmation that does not match,
   **When** the form is submitted, **Then** it is rejected with that reason.
6. **Given** someone adds a hidden "role: admin" field to the sign-up form, **When** it is
   submitted, **Then** the account is still created as a reader.
7. **Given** a signed-in person, **When** they open the sign-up or sign-in page, **Then**
   they are sent to the home page.
8. **Given** many sign-up attempts from one network address in a short time, **When** the
   limit is passed, **Then** further attempts are refused with "Try again later."
9. **Given** the forgot-password and reset-password pages, **When** they open, **Then** they
   show the same logo and design as sign-in.
10. **Given** 5 sign-in attempts for the same email within 15 minutes, from any mix of
    network addresses, **When** a 6th is made, even with the correct password, **Then** it
    is refused with the same "Try another email address or password." message as a wrong
    password.
11. **Given** an account that has been blocked, **When** its owner signs in with the correct
    password, **Then** sign-in is refused with that same generic message.
12. **Given** a signed-in person whose account is blocked meanwhile, **When** they make their
    next request, **Then** they are signed out and see "Your account has been blocked."
13. **Given** repeated wrong passwords lock an account, **When** the lock starts, **Then** the
    owner receives one email saying the account was locked, with a link to reset the
    password. Resetting it lifts the lock.
14. **Given** a blocked account, **When** its owner resets the password, **Then** the account
    stays blocked and no lock email is ever sent to it.

---

### User Story 9 - Links that look right when pasted into other apps (Priority: P3)

When someone pastes a DevLibrary link into WhatsApp, Slack, iMessage, Discord or similar
apps, the preview card shows the DevLibrary logo, name and tagline. A link to a published
book's page shows that book's cover, title and author instead. Opening any link still
requires signing in.

**Why this priority**: It makes shared links recognizable and inviting, but nothing else
depends on it.

**Independent Test**: Request the home page and book pages the way a link-preview app
does (signed out), and check the preview information each one returns.

**Acceptance Scenarios**:

1. **Given** the home page link, **When** it is pasted into a messaging app, **Then** the
   preview shows the DevLibrary logo on its dark background, "Dev Library" and the
   tagline.
2. **Given** a link to a published book with a cover, **When** it is pasted, **Then** the
   preview shows the book's cover, title and author names.
3. **Given** a published book without a cover, **When** its link is pasted, **Then** the
   preview shows the book's title and author with the branded DevLibrary image.
4. **Given** a link to a draft, archived or deleted book, **When** it is pasted, **Then** the
   preview is the generic branded one and reveals nothing about the book.
5. **Given** any book preview, **When** it is inspected, **Then** it contains no
   description, reviews, rating, file, or anything about who shared the link.
6. **Given** a signed-out person taps a book link, **When** it opens, **Then** they are sent
   to sign-in and land on that book's page afterwards.
7. **Given** a book was unpublished after its link was shared, **When** an app fetches the
   preview again, **Then** it gets the generic branded preview, and the book's preview
   image no longer loads.

---

### Edge Cases

- **Missing cover**: cards, the collection row and the book page show a placeholder with
  the title.
- **Long titles and names**: titles are cut to two lines on cards with the full title
  available. Long reviewer names do not break the layout.
- **Emoji everywhere**: titles, descriptions, reviews and names show emoji (including
  flags and skin tones) correctly.
- **Book removed while browsing**: a card for a deleted book leads to "not available", not
  an error page.
- **Book file replaced**: if the saved page no longer exists, the reader opens at the
  nearest valid page, or at the beginning.
- **Two devices reading at once**: the most recent reading wins, as defined in 001.
- **Leaving mid-turn**: closing the reader during a page animation saves the page being
  turned to.
- **Slow or large files**: the reader shows a loading state and opens a large book on the
  saved page without waiting for the whole file.
- **Unreadable file**: if a book file cannot be opened, the reader says so and offers a way
  back. It never shows a blank screen.
- **Search text of only spaces**: treated as an empty search.
- **Session expired while reading**: page turns are not lost. The person is asked to sign in
  again, and the pending position is saved after they do.
- **Account blocked while reading**: the next position save is refused, the person is
  signed out, and nothing more is saved for that account.
- **Large collection**: the collection row stays smooth, and covers load as they come into
  view.

## Requirements *(mandatory)*

### Functional Requirements

**Home page**

- **FR-001**: The home page MUST be available only to signed-in people. Signed-out
  visitors MUST be sent to sign-in and returned to the home page afterwards.
- **FR-002**: The home page MUST show a search box centered at the top.
- **FR-003**: The home page MUST list published books, most recently published first, 50 at
  a time. A "See more" control MUST load the next 50 below the ones already shown and MUST
  disappear when no more books remain.
- **FR-004**: Loading more MUST NOT repeat or skip books, even if books are published or
  removed between loads.
- **FR-005**: Every book card MUST show the cover (or a placeholder) with the title below.
  Tapping the card MUST open the book page, and every card MUST also offer a one-tap "Read"
  action.
- **FR-006**: When the person's collection has at least one book, the home page MUST show a
  "Your collection" row above the newest books. With an empty collection, it MUST NOT be
  shown.
- **FR-007**: The collection row MUST include every book in the person's collection, with
  cover, title and percentage read. It MUST be ordered by most recently read, then most
  recently added, and MUST scroll sideways by touch, trackpad, mouse and keyboard.
- **FR-008**: Tapping a book in the collection row MUST open it directly in the reader at
  the person's saved position.

**Search results**

- **FR-009**: Submitting the home search box MUST show matching published books in the same
  card layout, using the 001 search rules (001 FR-023–FR-026): text matches title or
  author, ignoring case and accents.
- **FR-010**: Results MUST offer a category dropdown (all categories by default) and a sort
  dropdown (Relevance, Newest, Title A–Z, Title Z–A, Top rated, with the 001 defaults).
  Changing either MUST keep the search text.
- **FR-011**: Results MUST load 50 at a time with "See more", like the home page. If the
  catalog changes between loads, a book already shown MUST NOT be shown a second time.
- **FR-012**: A search with no matches MUST say so and offer a way back to the home page.

**Book page**

- **FR-013**: The book page MUST show the cover, title, authors, categories, rich-text
  description (with emoji), a "Read" action, the average rating, and the review count.
- **FR-014**: The book page MUST list reviews newest first, each with the author's name,
  star rating, rich-text content and date, 20 at a time with "See more reviews".
- **FR-015**: A signed-in person who has not reviewed a published book MUST see a review
  form with a required 1–5 star rating and required rich-text content with an emoji
  picker (001 FR-044).
- **FR-016**: A new or changed review MUST appear, and the average and count MUST update,
  without a full page reload. Rejected input MUST show what is wrong and keep what the
  person wrote.
- **FR-017**: A person who has reviewed the book MUST see their own review in place of the
  form, with edit and delete actions. Editing MUST open in a modal (constitution
  Principle I).
- **FR-018**: Admins MUST see a delete action on every review (001 FR-046). Nobody else
  may change or delete another person's review, and this MUST be enforced on the server.
- **FR-019**: Archived books MUST show their reviews but no review form. Drafts and deleted
  books MUST show "not available" to readers (001 FR-017, FR-055).
- **FR-020**: The book page MUST let the person add the book to or remove it from their
  collection, and toggle it as a favorite with a heart (001 FR-027, FR-028, FR-032).

**Reader**

- **FR-021**: Every book a person can see MUST open in the in-app reader with one action,
  without downloading it or adding it to the collection first.
- **FR-022**: The reader MUST open at the person's saved position for that book (001
  FR-036), on any device, or at the beginning if there is none. If the saved position no
  longer exists in the file, it MUST open at the nearest valid position.
- **FR-023**: Every page turn or location change MUST save the position automatically. A
  save interrupted by leaving the page, closing the app, a lost connection or an expired
  session MUST be retried until it succeeds. The most recent position MUST win.
- **FR-024**: The reader MUST read PDF, EPUB and CBZ books. A CBR book MUST open to a clear
  "this comic can't be opened in the reader yet" message with a way back, never a blank
  or broken screen. In-app CBR reading is deferred (see Assumptions).
- **FR-025**: Pages MUST turn by tapping the page edges and swiping on touch screens, and
  with the arrow, Page Up/Page Down and space keys on a keyboard. All of these MUST follow
  the effective reading direction (001 FR-039).
- **FR-026**: The person MUST be able to switch the reading direction from inside the
  reader. The choice is saved for them and that book only.
- **FR-027**: Reflowable books MUST support at least five text sizes and the light, sepia
  and dark themes, keeping the current passage in view when either changes.
- **FR-028**: Fixed-layout pages (PDF, comics, manga) MUST fit the screen by default and
  support zoom and pan, including pinch-zoom on touch screens.
- **FR-029**: The reader MUST show the percentage read and the position in the book, and
  MUST indicate the beginning and the end instead of turning past them.
- **FR-030**: Nothing decorative (animated backgrounds, gradients, art) may appear behind or
  over book content (constitution Principle IV).

**Page-turn animation and reading settings**

- **FR-031**: Page turns MUST be animated by default. The animation MUST move in the
  reading direction, MUST be short (well under half a second), and MUST be interruptible
  so quick repeated turns never skip pages or leave a page half-turned.
- **FR-032**: The person MUST be able to switch the animation off, so pages change
  instantly, and back on. The setting MUST be saved on their account and apply to every
  book on every device.
- **FR-033**: The reader theme and text size MUST also be saved on the account.
- **FR-034**: Reading settings MUST be changeable from inside the reader and from a
  "Reading settings" item in the account menu. Changes MUST take effect at once.
- **FR-035**: When the device asks apps to reduce motion, pages MUST change instantly
  whatever the animation setting is.

**Everywhere**

- **FR-036**: Every screen in this feature MUST work on phones first and on desktops, with
  the same information and actions on both (constitution Principle III). Touch targets
  MUST be at least 44 px.
- **FR-037**: Every screen MUST follow `DESIGN.md` (constitution Principle IV), with a
  shared navigation bar that shows the full DevLibrary logo (with its name) on the left
  side, linking to the home page, and an account menu (reading settings, sign out) on the
  right.
- **FR-038**: Personal data (collection, positions, settings, favorites) MUST be visible and
  changeable only by its owner (001 FR-035).

**Sign-up and branding**

- **FR-039**: A signed-out visitor MUST be able to create an account from a sign-up page
  linked from sign-in, by giving a name, an email, a password and a password confirmation.
  The 001 account rules apply:
  - the name is required (001 FR-005);
  - the email is trimmed, lowercased, well-formed and unique (001 FR-001, FR-003);
  - the password is 8 to 72 characters (001 FR-004);
  - the account is always a reader, and the role is never taken from the form (001 FR-006).
- **FR-040**: After signing up, the person MUST be signed in and land on the home page, or
  on the page they were trying to open. Their empty collection with its Favorites shelf
  already exists (001 FR-012).
- **FR-041**: A rejected sign-up MUST say what is wrong and keep the name and email that
  were typed, never the password.
- **FR-042**: Sign-up attempts MUST be limited per network address at the same rate as
  sign-in's per-address limit (10 per 3 minutes), with the message "Try again later." A signed-in person opening the
  sign-up or sign-in page MUST be sent to the home page.
- **FR-043**: Sign-in, sign-up, forgot password and reset password MUST share one branded
  design, with the full DevLibrary logo at the top, following `DESIGN.md`.
- **FR-044**: The browser tab icon (favicon), the home-screen icon and the installed-app
  icon MUST use the DevLibrary book-stack logo, replacing the default red circle.
- **FR-045**: The logo MUST NOT appear on the reading surface (FR-030). The reader toolbar
  keeps only its controls.

**Link previews**

- **FR-046**: Every DevLibrary link pasted into a messaging or social app MUST produce a
  branded preview: the DevLibrary logo on its dark background, the name "Dev Library" and
  a one-line tagline.
- **FR-047**: A link to a **published** book's page MUST instead produce a preview with that
  book's cover (or the branded image if it has none), its title and its author names.
  These three are the only book details available without signing in. The description,
  reviews, rating, categories, book file and anything about the person who shared the link
  MUST NOT be exposed.
- **FR-048**: Links to draft, archived or deleted books MUST produce only the generic
  branded preview. The cover image used in a book preview MUST stop loading once the book
  is no longer published.
- **FR-049**: Opening any link in a browser without a session MUST still lead to sign-in
  and then to the requested page (FR-001, 001 FR-054). The preview information MUST NOT
  let anyone read, download or see anything else about the book.

**Account protection** (same approach as DevCine and Spotsby, on top of the 001 lockout)

- **FR-050**: Sign-in MUST be limited in two ways at once: per network address (10 per
  3 minutes, 001 FR-007) and per email address (5 per 15 minutes, whatever network
  addresses the attempts come from). A throttled attempt MUST get exactly the same response
  as a wrong password ("Try another email address or password."), so the limits are never
  advertised. This replaces the "Try again later." message 001 used for the per-address
  limit.
- **FR-051**: An account MUST be able to be blocked and unblocked by the maintainers.
  A blocked account MUST NOT be able to sign in. The refusal is the same generic message,
  so being blocked is never revealed at sign-in. Blocking is separate from the role and
  from the lockout. Neither a password reset nor the end of a lockout may unblock it.
- **FR-052**: When an account is blocked, every session it has MUST stop working. On their
  next request, a signed-in person is signed out and shown "Your account has been
  blocked." Requests made in the background (such as saving the reading position) are
  refused without saving anything.
- **FR-053**: When repeated wrong passwords lock an account (001 FR-008), its owner MUST
  receive one email per lockout saying the account was locked, with a link to reset the
  password. The reset lifts the lock (001 FR-010). Blocked accounts never get this email.
- **FR-054**: Failed attempts on a blocked or already-locked account MUST NOT count toward
  a new lockout or send another email.

### Key Entities

- **Reading Settings**: one set per account: page-turn animation on/off (on by default),
  reader theme (light, sepia or dark; light by default) and text size (default medium).
  Applies to every book.
- **Reading Position** *(from 001)*: one per person per book. Gives the reader its starting
  place and gets updated on every page turn. Also holds the person's direction choice for
  that book.
- **Account** *(from 001, extended)*: created by the new sign-up page with the 001 rules.
  The role is always reader. It gains a **blocked** state (blocked or not, and since when)
  that is separate from its role and its lockout.
- **Book**, **Review**, **Category**, **Personal Library**, **Library Entry**, **Shelf**
  *(from 001)*: read and changed through the screens in this feature, with the rules
  already defined there.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With 10,000 published books, the home page and every "See more" load return
  in under 1 second for 95% of requests.
- **SC-002**: In 100% of automated test cases across PDF, EPUB, comic and right-to-left
  manga, reopening a book lands on the last saved position.
- **SC-003**: Zero lost page turns in automated tests that close the tab, go offline or
  expire the session right after a page turn.
- **SC-004**: With the animation off, the next page shows within 100 ms of the tap. With it
  on, the animation finishes within 350 ms.
- **SC-005**: A 500 MB PDF opens on its saved page within 5 seconds on a typical broadband
  connection, without downloading the whole file first.
- **SC-006**: In 100% of test cases, "See more" never repeats or skips a book, including when
  books are published between loads.
- **SC-007**: A posted review appears, with the updated average and count, within 1 second
  of submitting, without a page reload.
- **SC-008**: Every user story passes its acceptance scenarios on a phone-sized screen
  (390 × 844) and a desktop screen (1440 × 900).
- **SC-009**: A new person can go from the sign-in page to the signed-in home page through
  sign-up in under 1 minute, and 100% of accounts created through sign-up are readers,
  whatever extra fields are submitted.
- **SC-010**: In 100% of automated checks, a signed-out preview request for a published
  book returns its cover, title and authors and nothing else about it. Every other link,
  including draft, archived and deleted books, returns only the branded preview. Pasting a
  published book link into WhatsApp, Slack, iMessage and Discord during live verification
  shows the book's card.
- **SC-011**: In 100% of automated checks:
  - a 6th sign-in attempt for one email within 15 minutes is refused, whatever mix of
    network addresses is used;
  - a blocked account can neither sign in nor keep using an existing session;
  - every throttled, locked, blocked, unknown-email and wrong-password attempt gets an
    identical response.

## Assumptions

- "Cape" means the book's **cover**. "Your collection" is the personal library from 001.
- "Most recent books" means most recently **published**.
- "Open on the page using the selected page by the user account" means the reading
  position saved for the signed-in account (001 FR-036), not a page stored on the device.
- The collection row shows the whole collection in one sideways-scrolling row. A full
  library page with shelves and search comes in a later feature.
- Tapping a book in the collection row opens the reader. Tapping a catalog card opens the
  book page. Cards also have a "Read" action, so every visible book opens in the reader
  with one tap (constitution Principle V).
- The home search box leads to a results view with the category and sort dropdowns the
  original feature list described for search.
- The page-turn animation is a horizontal slide in the reading direction. On by default.
- Reader theme and text size are saved with the animation setting, because the
  constitution requires them in the reader and they belong to the same settings.
- Reviews keep the 001 rules: one per person per book, rating and text both required,
  published books only.
- The emoji picker is part of the review form. The phone's own emoji keyboard also works.
- Reading notes, bookmarks, download, convert and share are not part of this feature,
  although the reader leaves room for them in its toolbar.
- **Constitution dependency**: book link previews (FR-047) need constitution Principle
  VIII amended. Today it says every page and endpoint requires sign-in. The amendment
  must allow a signed-out preview of a **published** book limited to its cover, title and
  authors. It has to be ratified before the preview work is implemented.
- No email confirmation: a new account can be used at once. Confirmation can be added
  later without changing existing accounts.
- Account protection follows DevCine and Spotsby (FR-050–FR-054), but keeps the 001
  lockout policy: 5 failures, then a timed lock that doubles up to 24 h. DevCine instead
  locks until a reset after 15 failures. A lock that never expires on its own would let an
  attacker keep a real person out of their account (001 research R6).
- Blocking and unblocking are done by the maintainers from the console until an admin
  users screen exists.
- Messaging apps keep previews they have already fetched. Unpublishing a book stops new
  previews and the preview image, but cannot recall a preview another app already stored.
- **CBR reading is deferred** to its own feature. No CBR book can be added yet, since
  there is no admin upload screen and the seeds have none. Reading one well needs its pages
  prepared on the server first. Until then a CBR book shows the "can't be opened yet"
  message (FR-024).
- The 001 seed data (an admin, two readers, a PDF, an EPUB and a manga) plus larger
  multi-page sample files are enough to exercise every story.
