# Development seed data: one admin, two readers, two categories and three published books
# (a PDF, a reflowable EPUB and a right-to-left manga). Idempotent: safe to run repeatedly.
#
#   bin/rails db:seed

PASSWORD = "password123"
DOMAIN = "codeline.company"
FIXTURES = Rails.root.join("spec/fixtures/files")

def seed_user(email, name:, role: "reader")
  User.find_or_create_by!(email_address: email) do |user|
    user.name = name
    user.role = role
    user.password = PASSWORD
    user.password_confirmation = PASSWORD
  end
end

def seed_book(title, file:, authors:, categories:, kind: "book", cover: "reader/cover-1.png")
  Book.find_or_create_by!(title: title) do |book|
    book.authors = authors
    book.kind = kind
    book.status = "published"
    book.categories = categories
    book.description = "Seeded sample: #{title} 📚"
    book.file.attach(io: File.open(FIXTURES.join(file)), filename: file)
    book.cover.attach(io: File.open(FIXTURES.join(cover)), filename: File.basename(cover))
  end
end

seed_user("admin@#{DOMAIN}", name: "Admin", role: "admin")
seed_user("reader@#{DOMAIN}", name: "Reader One")
seed_user("reader2@#{DOMAIN}", name: "Reader Two")

fantasy = Category.find_or_create_by!(name: "Fantasy")
romance = Category.find_or_create_by!(name: "Romance")

seed_book("The Sample PDF", file: "sample.pdf", authors: [ "Ada Lovelace" ], categories: [ fantasy ])
seed_book("Café Noir", file: "sample.epub", authors: [ "José Saramago" ], categories: [ romance ], cover: "reader/cover-2.png")
seed_book("Sample Manga", file: "manga.cbz", authors: [ "Akira Toriyama" ], categories: [ fantasy ], kind: "manga", cover: "reader/cover-3.png")

# 120 more catalog books, published an hour apart, to page through the home page's newest
# list (002 US1). Every third one has a cover; the rest show the title placeholder.
COVERS = Dir[FIXTURES.join("reader/cover-*.png")].sort
120.times do |i|
  title = format("Seed Book %03d", i + 1)
  next if Book.exists?(title: title)

  book = Book.create!(title: title, authors: [ "Seed Author #{i % 12 + 1}" ], status: "published",
                      categories: [ i.even? ? fantasy : romance ]) do |b|
    b.file.attach(io: File.open(FIXTURES.join("sample.pdf")), filename: "sample.pdf")
    if (i % 3).zero?
      cover = COVERS[(i / 3) % COVERS.size]
      b.cover.attach(io: File.open(cover), filename: File.basename(cover))
    end
  end
  book.update_column(:published_at, Time.zone.local(2026, 9, 1) + i.hours)
end

puts "Seeded #{User.count} users, #{Category.count} categories, #{Book.count} books (password: #{PASSWORD})"

# reader@devlibrary.test keeps a collection (002 US2): three books with saved positions, read
# at different times, plus nine unread ones so the row scrolls. reader2 keeps none.
reader = User.find_by!(email_address: "reader@devlibrary.test")
{
  "Sample Manga" => { location: "2", progress: 50, read_at: 10.minutes.ago },
  "Café Noir" => { location: nil, progress: 40, read_at: 3.hours.ago },
  "The Sample PDF" => { location: "1", progress: 100, read_at: 1.day.ago }
}.each do |title, position|
  book = Book.find_by!(title: title)
  reader.library.add!(book)
  ReadingPosition.record!(user: reader, book: book, **position)
end
(110..118).each { |n| reader.library.add!(Book.find_by!(title: format("Seed Book %03d", n))) }

# Multi-page reader fixtures (002 US3): one per engine path, plus a right-to-left manga.
{
  "Reader Test PDF" => [ "reader/text-6-pages.pdf", "book", "reader/cover-1.png" ],
  "Reader Test EPUB" => [ "reader/reflowable-3-chapters.epub", "book", "reader/cover-2.png" ],
  "Reader Test Comic" => [ "reader/comic-4-pages.cbz", "comic", "reader/cover-3.png" ],
  "Reader Test Manga" => [ "reader/manga-rtl-4-pages.cbz", "manga", "reader/cover-4.png" ]
}.each do |title, (file, kind, cover)|
  seed_book(title, file: file, authors: [ "DevLibrary" ], categories: [ fantasy ], kind: kind, cover: cover)
end
