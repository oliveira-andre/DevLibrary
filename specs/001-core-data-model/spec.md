# Feature Specification: Core Data Model

**Feature Branch**: `main` (no feature branch created)

**Created**: 2026-10-13

**Status**: Draft

**Input**: User description: "this time i am about to give you enough context telling you the future features, dont implement them right i just wanna you to imagine the database and generate the migrations with models and relationships, probably the validations as well. so people will login with email and password, we will have rate limit, but not only by ip we need to block the user incase of too much tries because they are trying to guesse the password with proxies, add name to the users blank by default he can update on his account later but on sign up make it required. dont forget email needs to be saved with .downcased also when login with params email should be downcased. first feature will be the search we should have input to search, book category, as dropdown select and sort as dropdown select as well. books should have reviews, title, description, cape and of course the file i have already installed active storage, description will have rich text and emoticons to add. reviews will have stars 1-5 only and the content also with emoticons and rich text. and of course who made the review (logged in users only). user can favorite the book clicking on heart icon, favorite must be a category created with user and user collection (own library) own library can have one or multiple categories so user can separate the books and search for them inside the own collection, when user is reading it can make notes, also we must be able to support rich text and emoticons, these comments are just for the user of course, not touching the main reading experience, when user is reading it must as well save the last page of that book so then open on the same page when user gets out of the app or something like this, the book will show the cape on collection with the title bellow, when user clicks it will lead to reading page and the last page should show. app should be mobile first of course, so when testing you should have one for mobile screens and another one with desktop screens. user must be able to download on the desired version (pdf and epub or others) also also we msut be able to convert these versions, we also wanna be able to share the book but when sharing doesnt share from my collection but from the main page of the book so other person can get to his collections. of course i must be able to remove it from my collection without removing the book, books will be created, updated status or even removed only for admin users, normal users only can show and read them."

## Scope

This feature defines the data DevLibrary keeps and the rules that data must follow: the
records, how they relate, what makes them valid, who may change them, and what happens
when they are removed. It also hardens the existing sign-in with account lockout.

Screens are **out of scope** and will each get their own spec. That includes sign-up,
catalog search, the book page, the reader, the personal library, review and note editors,
and the download, convert and share actions. This feature makes sure each of those can be
built on top of it without reshaping the data later.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Accounts that resist password guessing (Priority: P1)

A person has an account identified by email and password, with a display name and a role
(reader or admin). Email is matched the same way regardless of capital letters or stray
spaces. Someone trying to guess a password from many different network addresses is
stopped, because the account itself locks after repeated failures.

**Why this priority**: The whole app sits behind sign-in, and every other record belongs
to an account.

**Independent Test**: Create accounts and simulate sign-in attempts against the account
rules. Normalization, required fields, roles and lockout can all be verified without any
screens.

**Acceptance Scenarios**:

1. **Given** someone signs up with email " Ana@Example.COM ", **When** the account is
   saved, **Then** the stored email is "ana@example.com".
2. **Given** an account for "ana@example.com", **When** someone signs in with
   "ANA@example.com " and the correct password, **Then** sign-in succeeds.
3. **Given** an account for "ana@example.com", **When** someone signs up with
   "Ana@example.com", **Then** sign-up is rejected because the email is already in use.
4. **Given** a sign-up with no name, **When** it is submitted, **Then** it is rejected with
   a "name is required" message.
5. **Given** an account created by the maintainers without a name, **When** it is saved,
   **Then** it is accepted with an empty name, and the person can add a name later from
   account settings.
6. **Given** 5 consecutive wrong passwords for one account, each from a different network
   address, **When** a 6th attempt is made with the correct password within 15 minutes,
   **Then** it is rejected because the account is locked.
7. **Given** a lock has expired, **When** the person signs in with the correct password,
   **Then** sign-in succeeds and the failure count resets to zero.
8. **Given** a locked account, **When** the person completes a password reset, **Then**
   the lock is lifted and the failure count resets.
9. **Given** a new account is created, **When** it is saved, **Then** it has the reader
   role and an empty personal library containing a "Favorites" shelf.

---

### User Story 2 - Admin-curated catalog (Priority: P1)

Admins manage the catalog. A book has a title, authors, a rich-text description that can
contain emoji, a cover, a readable file, a content type (book, comic, manga, storybook),
a reading direction, a status, and categories. Readers can only view and read published
books.

**Why this priority**: Every reader feature (search, library, reading, reviews) needs
books to exist.

**Independent Test**: Create, publish, archive and delete books as an admin, and attempt
the same as a reader. Each status, rule and permission can be verified without screens.

**Acceptance Scenarios**:

1. **Given** an admin adds a book with only a title, **When** it is saved, **Then** it is
   stored as a draft.
2. **Given** a draft with no book file, **When** an admin tries to publish it, **Then**
   publishing is rejected because a file is required.
3. **Given** a file that claims to be a PDF but is not, **When** an admin attaches it,
   **Then** it is rejected as an unsupported or unreadable file.
4. **Given** an admin sets the content type to manga, **When** the book is saved,
   **Then** its reading direction defaults to right-to-left, and the admin can change it
   to left-to-right.
5. **Given** a reader account, **When** it tries to create, edit, change the status of,
   or delete a book or category, **Then** the action is refused.
6. **Given** a draft book, **When** a reader looks for it, **Then** it is not visible.
7. **Given** a category named "Fantasy" exists, **When** an admin adds "fantasy",
   **Then** it is rejected as a duplicate.
8. **Given** a book's title changes, **When** its share link is used, **Then** the link
   still opens that book.

---

### User Story 3 - Personal library, shelves and favorites (Priority: P1)

Each person has their own library. They add catalog books to it, sort them onto shelves
they create, and mark favorites with a heart, which places the book on the built-in
"Favorites" shelf. They can search and filter inside their own library. Removing a book
from the library never removes it from the catalog.

**Why this priority**: The personal library is how people keep and find books, and it is
the main entry point back into reading.

**Independent Test**: Add, shelve, favorite and remove books for one account, and verify
another account sees none of it.

**Acceptance Scenarios**:

1. **Given** a published book not in the library, **When** the person taps the heart,
   **Then** the book is added to the library and placed on Favorites.
2. **Given** a favorited book, **When** the person taps the heart again, **Then** it leaves
   Favorites but stays in the library.
3. **Given** a book in the library, **When** the person adds it again, **Then** no
   duplicate is created.
4. **Given** shelves "Manga" and "To read", **When** the person places one book on both,
   **Then** it appears on both shelves.
5. **Given** a book on several shelves, **When** the person removes it from the library,
   **Then** it leaves every shelf (including Favorites), the catalog book still exists, and
   the person's reading position, notes and bookmarks for it are kept.
6. **Given** a shelf named "Manga", **When** the same person creates "manga", **Then** it
   is rejected as a duplicate. Another person can still create "Manga" for themselves.
7. **Given** the Favorites shelf, **When** the person tries to rename or delete it,
   **Then** the action is refused.
8. **Given** a custom shelf with books, **When** the person deletes the shelf, **Then** the
   books stay in the library.
9. **Given** a library with many books, **When** the person searches for text or picks a
   shelf, **Then** only matching books from their own library are returned.

---

### User Story 4 - Resume exactly where you stopped (Priority: P1)

While someone reads, their position in each book is saved. When they come back on any
device, the book opens at that position. They can also bookmark places and switch the
reading direction for themselves.

**Why this priority**: Resuming at the last page is the product's defining promise
(constitution Principle V).

**Independent Test**: Record positions, bookmarks and direction choices for an account
and book, and verify what is returned when the book is reopened.

**Acceptance Scenarios**:

1. **Given** a person was on page 42 of a PDF, **When** they reopen the book on another
   device, **Then** the saved position is page 42.
2. **Given** a person reads a book that is not in their library, **When** they change
   pages, **Then** their position is still saved.
3. **Given** a position saved at 10:05, **When** an update stamped 10:01 arrives later
   (for example from a phone that was offline), **Then** the 10:05 position is kept.
4. **Given** a manga that defaults to right-to-left, **When** the person switches it to
   left-to-right, **Then** that choice applies only to them and only to that book, and is
   restored the next time they open it.
5. **Given** a bookmark on page 10, **When** the person bookmarks page 10 again, **Then**
   no duplicate bookmark is created.

---

### User Story 5 - Private reading notes (Priority: P2)

While reading, a person writes notes with rich text and emoji. Each note is tied to the
place in the book where it was written. Notes are visible only to their author and never
change the book itself.

**Why this priority**: Valuable for study and recall, but reading works without it.

**Independent Test**: Create, edit and delete notes for one account and verify that no
other account can see or change them.

**Acceptance Scenarios**:

1. **Given** a person on page 15, **When** they save a note "Great twist 🤯", **Then** the
   note is stored with that position and the emoji intact.
2. **Given** a person submits an empty note, **When** it is saved, **Then** it is rejected.
3. **Given** another person's note, **When** someone tries to read, edit or delete it,
   **Then** the action is refused.
4. **Given** a book with notes on pages 30, 5 and 12, **When** the author lists their
   notes for that book, **Then** they appear in book order: 5, 12, 30.

---

### User Story 6 - Reviews and ratings (Priority: P2)

Signed-in people review published books with a 1–5 star rating and a rich-text comment
that can contain emoji. Each review shows who wrote it. Each book's average rating and
review count stay accurate and are used to sort the catalog.

**Why this priority**: Helps people choose books; the catalog is still usable without it.

**Independent Test**: Create, change and delete reviews and verify the rules and the
book's average rating and review count.

**Acceptance Scenarios**:

1. **Given** a published book, **When** a person submits 4 stars with a comment, **Then**
   the review is saved under their name and the book's average and count update.
2. **Given** a rating of 0, 6 or 3.5, **When** it is submitted, **Then** it is rejected.
3. **Given** a person has already reviewed a book, **When** they submit another review
   for it, **Then** it is rejected, and they can edit their existing review instead.
4. **Given** a review, **When** its author deletes it, **Then** the book's average and
   count update to exclude it.
5. **Given** any review, **When** an admin removes it, **Then** it is deleted.
6. **Given** a draft book, **When** anyone tries to review it, **Then** the review is
   rejected.

---

### User Story 7 - Search with category and sort (Priority: P2)

The catalog can be searched by text, filtered by one category, and sorted. This is the
data behind the search page, the first screen feature after this one: a text input, a
category dropdown and a sort dropdown.

**Why this priority**: Search is the first screen feature planned, and it needs these
rules to exist first.

**Independent Test**: Seed a catalog and run searches with each combination of text,
category and sort, checking the results and their order.

**Acceptance Scenarios**:

1. **Given** a published book titled "Café Noir", **When** someone searches "cafe",
   **Then** it is returned (matching ignores case and accents).
2. **Given** published books in "Fantasy" and "Romance", **When** someone filters by
   "Fantasy", **Then** only Fantasy books are returned.
3. **Given** search text, **When** no sort is chosen, **Then** results are ordered by
   relevance. With no search text, they are ordered newest first.
4. **Given** "Top rated" is chosen, **When** results are returned, **Then** they are
   ordered by average rating, with ties broken by review count.
5. **Given** draft and archived books match the text, **When** someone searches, **Then**
   they are not returned.

---

### User Story 8 - Download and convert (Priority: P3)

People download a book in its original format, or ask for a PDF or EPUB copy. Conversions
are produced once per book version and shared with everyone who asks for them.

**Why this priority**: Important for taking books elsewhere, but in-app reading comes
first.

**Independent Test**: Request conversions for a book and verify the status, reuse, retry
and replacement rules.

**Acceptance Scenarios**:

1. **Given** a published EPUB, **When** a person asks for a PDF copy, **Then** a pending
   conversion is recorded for that book version and target format.
2. **Given** a completed PDF conversion of that version, **When** another person asks for
   a PDF, **Then** the existing one is reused and no new conversion is created.
3. **Given** a book whose original is a PDF, **When** someone asks to convert it to PDF,
   **Then** the request is refused and the original is offered instead.
4. **Given** a failed conversion, **When** someone retries, **Then** it is attempted again
   and the failure reason from the last attempt is kept until it succeeds.
5. **Given** an admin replaces a book's file, **When** the replacement is saved, **Then**
   all earlier conversions of the old file are discarded and the new file becomes the
   book's original.

---

### User Story 9 - Share a book (Priority: P3)

A person shares a book. The link always points to the book's own page in the catalog,
never to the sharer's library, so the recipient can add it to their own library.

**Why this priority**: Helps people discover books, but nothing else depends on it.

**Independent Test**: Generate share links and resolve them as different accounts and as
a signed-out visitor.

**Acceptance Scenarios**:

1. **Given** a person shares a book from their library, **When** the link is produced,
   **Then** it points to the book's catalog page and reveals nothing about the sharer's
   library or shelves.
2. **Given** a signed-out recipient opens the link, **When** they sign in, **Then** they
   arrive at that book's page and can add it to their own library.
3. **Given** the shared book was deleted or is a draft, **When** a reader opens the link,
   **Then** they are told the book is not available.

---

### Edge Cases

- **Two people, one email**: emails that differ only by case or surrounding spaces count
  as the same email and cannot be registered twice.
- **Unknown email at sign-in**: the failure message is the same as for a wrong password or
  a locked account. It never reveals whether an account exists or is locked.
- **Lockout keeps escalating**: each new lockout without a successful sign-in in between
  lasts twice as long as the previous one (15 min, 30 min, 1 h…), capped at 24 hours.
- **Admin deletes a book**: the book, its file, cover and conversions are removed, along
  with every person's library entry, shelf placements, reading position, notes, bookmarks
  and reviews for it. Its share link stops working. Archiving is the non-destructive
  alternative.
- **Archived book in someone's library**: it disappears from search and the catalog, but
  people who already have it in their library can still open, read, download and convert
  it.
- **Book file replaced**: saved positions are kept. If a saved position no longer exists
  in the new file, the reader opens at the nearest valid position, or at the beginning.
- **Account deleted**: its library, shelves, reading positions, bookmarks, notes and
  reviews are deleted. Book averages and counts update.
- **Category deleted**: it is removed from every book that had it. No book is deleted.
- **Emoji everywhere**: names, titles, shelf names, descriptions, reviews and notes store
  and show full emoji (including multi-part emoji such as flags and skin tones) without
  corruption.
- **Two devices reading at once**: the position with the most recent reading time wins.

## Requirements *(mandatory)*

### Functional Requirements

**Accounts and sign-in protection**

- **FR-001**: An account MUST have an email address and a password. The email MUST be
  stored with surrounding spaces removed and in lowercase, and MUST be unique regardless
  of case.
- **FR-002**: The email entered at sign-in MUST be trimmed and lowercased before it is
  matched to an account.
- **FR-003**: The email MUST be a well-formed address.
- **FR-004**: The password MUST be 8 to 72 characters long.
- **FR-005**: An account MUST have a name, empty by default. The name MUST be required
  when a person signs up themselves. It can be changed later from account settings, but
  once set it cannot be cleared. Maximum 100 characters.
- **FR-006**: An account MUST have exactly one role, reader or admin, with reader as the
  default. Self sign-up MUST always create a reader. Only an existing admin or the
  maintainers can grant the admin role.
- **FR-007**: The existing limit on sign-in attempts per network address MUST remain in
  place.
- **FR-008**: The system MUST count consecutive failed sign-in attempts per account,
  regardless of network address. After 5 consecutive failures the account MUST lock for
  15 minutes. Each further lockout without a successful sign-in in between MUST double the
  lock duration, up to a maximum of 24 hours.
- **FR-009**: While an account is locked, sign-in MUST be refused even with the correct
  password.
- **FR-010**: A successful sign-in or a completed password reset MUST reset the failure
  count and lift any lock.
- **FR-011**: Sign-in failure messages MUST be identical for an unknown email, a wrong
  password and a locked account.
- **FR-012**: Creating an account MUST also create that person's empty personal library
  and its built-in "Favorites" shelf.

**Catalog**

- **FR-013**: A book MUST have a title (required, max 255 characters). It MAY have one or
  more author names, a rich-text description that supports emoji, and a cover image.
- **FR-014**: A book MUST have at most one book file. Accepted formats are PDF and EPUB
  (first-class), plus CBZ and CBR for comics. The format MUST be checked from the file's
  actual contents, not its name. Book files up to 500 MB are accepted. Covers MUST be
  JPEG, PNG or WebP images up to 10 MB.
- **FR-015**: A book MUST have a content type of book, comic, manga or storybook, with
  book as the default.
- **FR-016**: A book MUST have a reading direction. It defaults to right-to-left for
  manga and left-to-right for everything else, and an admin MAY change it.
- **FR-017**: A book MUST have a status of draft (default), published or archived.
  Drafts are visible only to admins. Published books are visible to every signed-in
  person. Archived books are hidden from the catalog and search, but stay available to
  people who already have them in their library.
- **FR-018**: A book MUST NOT be published without a title and a book file.
- **FR-019**: Categories MUST be managed by admins and have a name that is required,
  unique regardless of case, and at most 50 characters. A book MAY belong to zero or more
  categories. Deleting a category MUST NOT delete any book.
- **FR-020**: Only admins MUST be able to create, edit, change the status of, or delete
  books and categories. Readers can only view and read books visible to them.
- **FR-021**: Each book MUST have a stable public identifier for its share link. The
  identifier MUST NOT change when the title or other details change.
- **FR-022**: Deleting a book MUST permanently remove its file, cover and conversions,
  plus every library entry, shelf placement, reading position, bookmark, note and review
  linked to it.

**Search**

- **FR-023**: Search MUST return only published books whose title or author names match
  the search text. Matching MUST ignore case and accents and accept partial words.
- **FR-024**: Search MUST optionally filter by a single category. With no category
  chosen, all categories are included.
- **FR-025**: Search MUST offer these sort orders: Relevance (available only with search
  text, and the default then), Newest (the default without search text), Title A–Z,
  Title Z–A, and Top rated (average rating, ties broken by review count).
- **FR-026**: Text, category and sort MUST combine freely in one search.

**Personal library and shelves**

- **FR-027**: A person MUST be able to add any published book to their library. Adding a
  book already in the library MUST NOT create a duplicate.
- **FR-028**: Removing a book from the library MUST remove it from all of that person's
  shelves, including Favorites. It MUST NOT delete the catalog book or the person's
  reading position, bookmarks or notes for it.
- **FR-029**: A person MUST be able to create, rename and delete their own shelves. Shelf
  names are required, at most 50 characters, and unique per person regardless of case.
  "Favorites" is reserved.
- **FR-030**: The Favorites shelf MUST NOT be renamed or deleted.
- **FR-031**: A library book MAY be on any number of that person's shelves. Placing a
  book on a shelf MUST add it to the library if it is not already there. Deleting a shelf
  MUST NOT remove its books from the library.
- **FR-032**: Favoriting a book MUST place it on Favorites, adding it to the library if
  needed. Unfavoriting MUST remove it from Favorites only.
- **FR-033**: A person MUST be able to search their own library by title or author and
  filter it by shelf.
- **FR-034**: For each library book the system MUST provide the cover, the title and the
  saved reading position, so the library can show the cover with the title below and open
  the reader at the last position.
- **FR-035**: Libraries and shelves MUST be visible and changeable only by their owner.

**Reading position, direction and bookmarks**

- **FR-036**: The system MUST keep one reading position per person per book. It records
  the location (page number for PDF and image-based books, or a position within the text
  for EPUB), the percentage read (0–100) and the time it was last read.
- **FR-037**: Reading positions MUST be saved whether or not the book is in the person's
  library.
- **FR-038**: A position update stamped earlier than the saved position MUST NOT replace
  it.
- **FR-039**: A person MAY set their own reading direction for a book. It applies only to
  them and only to that book. When they have not set one, the book's direction applies.
- **FR-040**: A person MUST be able to bookmark positions in a book, each with an
  optional label (max 100 characters). Two bookmarks of the same book at the same
  position MUST NOT exist for one person. Bookmarks are private to their owner.

**Notes**

- **FR-041**: A person MUST be able to write notes on a book. Each note is tied to the
  position where it was written. Note content is rich text that supports emoji, is
  required, and is at most 10,000 characters.
- **FR-042**: Notes MUST be visible and changeable only by their author, and MUST NEVER
  alter the book's content.
- **FR-043**: A person's notes for a book MUST be listable in book order.

**Reviews**

- **FR-044**: A signed-in person MUST be able to review a published book. A review has a
  required whole-number rating from 1 to 5 and required rich-text content that supports
  emoji, at most 5,000 characters. Each review records its author.
- **FR-045**: A person MUST have at most one review per book. They MAY edit or delete
  their own review.
- **FR-046**: Admins MUST be able to delete any review.
- **FR-047**: Each book's average rating and review count MUST stay accurate after every
  review is created, edited or deleted.

**Downloads and conversions**

- **FR-048**: A person MUST be able to download any book visible to them in its original
  format.
- **FR-049**: A person MUST be able to request a PDF or EPUB copy of a book whose
  original is a different format. There MUST be at most one conversion per book file
  version per target format, and it is shared by everyone who requests it.
- **FR-050**: A conversion MUST record its status (pending, processing, completed or
  failed), who first requested it, and, if it failed, the reason. A failed conversion MAY
  be retried.
- **FR-051**: Converting MUST NEVER modify the original file. Replacing a book's file
  MUST discard every conversion of the previous file.
- **FR-052**: Book files and conversions MUST only be delivered to signed-in people
  allowed to see the book, never through a permanent public link.

**Sharing**

- **FR-053**: A share link MUST point to the book's catalog page using its stable public
  identifier, and MUST NOT include anything about the sharer's library or shelves.
- **FR-054**: A signed-out recipient opening a share link MUST be sent to sign-in, then
  returned to that book's page.
- **FR-055**: A share link to a draft or deleted book MUST tell the recipient the book is
  not available. An archived book's link MUST work only for people who have it in their
  library.

**Text content**

- **FR-056**: Every text a person or admin enters (names, titles, shelf names, category
  names, descriptions, reviews, notes, labels) MUST store and show full Unicode text,
  including emoji, without corruption.

### Key Entities

- **Account**: A person who can sign in. Email (normalized, unique), password, name,
  role (reader or admin), and sign-in protection state (consecutive failures, lock expiry,
  number of consecutive lockouts). Has one personal library, and many sessions, reading
  positions, bookmarks, notes and reviews.
- **Sign-in Session**: An active signed-in device for an account (already exists).
- **Book**: A catalog item. Title, author names, rich-text description, cover, book file,
  original format, content type, reading direction, status, stable public identifier,
  average rating and review count. Belongs to zero or more categories. Has many reviews,
  conversions, library entries, reading positions, bookmarks and notes.
- **Category**: An admin-managed genre used to filter the catalog. Unique name. Linked to
  many books.
- **Personal Library**: The single, private collection belonging to one account, created
  with the account. Has many library entries and shelves.
- **Library Entry**: One book in one person's library, with the date it was added.
  Unique per library and book. Can sit on many shelves.
- **Shelf**: A named group a person creates inside their library. Exactly one per library
  is the built-in Favorites shelf. Name unique per library. Holds many library entries.
- **Shelf Placement**: One library entry on one shelf. Unique per shelf and entry.
- **Reading Position**: One per person per book. Location, percentage read, last-read
  time, and the person's optional reading-direction choice for that book.
- **Bookmark**: A saved position in a book for one person, with an optional label.
  Unique per person, book and position.
- **Note**: A private rich-text note by one person on one book, tied to a position.
- **Review**: One person's rating (1–5) and rich-text comment on one published book.
  Unique per person and book.
- **Conversion**: A PDF or EPUB copy of one version of a book's file. Target format,
  status, failure reason, the person who first requested it, and the resulting file.
  Unique per book, file version and target format.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of email variations that differ only in case or surrounding spaces
  resolve to the same account, in both sign-up and sign-in checks.
- **SC-002**: Once an account has had 5 consecutive failed attempts, 100% of further
  attempts during the lock are refused, however many network addresses they come from.
- **SC-003**: In 100% of test cases, reopening a book returns the most recently saved
  position, and an older position never overwrites a newer one.
- **SC-004**: Removing a book from a library leaves the catalog book and every other
  person's data unchanged in 100% of test cases.
- **SC-005**: Zero cases where one person can see or change another person's library,
  shelves, positions, bookmarks or notes across the automated permission checks.
- **SC-006**: 100% of ratings outside whole numbers 1–5 are rejected, and book averages
  match a manual recalculation after every review change.
- **SC-007**: On a catalog of 10,000 books, 95% of searches return results in under
  1 second.
- **SC-008**: Repeated requests for the same conversion of the same book version produce
  exactly one conversion in 100% of test cases.
- **SC-009**: Every rule in this spec has at least one automated check, and the planned
  screen features (search, library, reader, reviews, notes, downloads, sharing) can each
  be planned without restructuring or deleting data defined here.

## Assumptions

- "Cape" in the request means the book's **cover**.
- This feature builds on the sign-in already in the app: email and password, sign-in
  sessions, password reset, and a per-address limit of 10 attempts per 3 minutes.
- The data structures, relationships and validations requested in the input are built
  when this spec is implemented, after `/speckit-plan` and `/speckit-tasks`.
- Screens are separate future features, each with its own spec: sign-up, account
  settings, search page, book page, reader, library, review and note editors, and
  download, convert and share actions.
- Lockout policy: 5 consecutive failures; 15-minute first lock; doubling per further
  lockout; 24-hour cap. Telling the person by email that their account is locked belongs
  to the sign-in screens feature.
- Admin accounts are created by the maintainers. There is no admin-management screen in
  scope.
- The search page's category dropdown lists admin-managed **categories** (genres).
  Content type (book, comic, manga, storybook) is a separate attribute and could become
  its own filter later.
- Authors are free-text names, not separate records.
- Covers are optional. Screens show a placeholder when a cover is missing.
- A review requires both a rating and written content.
- Removing a book from a library keeps the person's reading position, notes and bookmarks,
  so re-adding the book restores them.
- Conversions are shared by everyone, because they are copies of the same catalog book.
- Downloads offer the original format plus PDF and EPUB conversions. No other conversion
  targets exist (constitution Principle VII).
- Screen features will be tested on both mobile-sized and desktop-sized screens. This
  feature has no screens, so its checks are on the data and its rules.
