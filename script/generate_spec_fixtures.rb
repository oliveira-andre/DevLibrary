#!/usr/bin/env ruby
# Writes the tiny book and cover files used by specs into spec/fixtures/files/, plus the
# multi-page reader fixtures in spec/fixtures/files/reader/.
# Stdlib only; ZIP-based formats shell out to the `zip` CLI.
#
#   ruby script/generate_spec_fixtures.rb

require "base64"
require "fileutils"
require "tmpdir"
require "zlib"

OUT = File.expand_path("../spec/fixtures/files", __dir__)
FileUtils.mkdir_p(OUT)

PNG  = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=")
GIF  = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")
JPEG = Base64.decode64("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=")
WEBP = Base64.decode64("UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==")

def write(name, bytes)
  File.binwrite(File.join(OUT, name), bytes)
  puts "wrote #{name} (#{bytes.bytesize} bytes)"
end

def zip(name, files, stored_first: nil)
  Dir.mktmpdir do |dir|
    files.each do |path, bytes|
      full = File.join(dir, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.binwrite(full, bytes)
    end
    target = File.join(OUT, name)
    FileUtils.rm_f(target)
    Dir.chdir(dir) do
      # -X: no extra fields, so an uncompressed first entry's name starts at byte 30.
      system("zip", "-q", "-X", "-0", target, stored_first, exception: true) if stored_first
      rest = files.keys - [ stored_first ]
      system("zip", "-q", "-X", "-9", target, *rest, exception: true)
    end
    puts "wrote #{name} (#{File.size(target)} bytes)"
  end
end

# One page per text. Objects: 1 catalog, 2 page tree, then a page and its content stream for
# each text, then the shared font (a single page keeps the original 5-object layout).
def pdf(*texts, size: [ 300, 200 ], font_size: 18, at: [ 20, 100 ])
  font_ref = 3 + texts.size * 2
  kids = texts.each_index.map { |index| "#{3 + index * 2} 0 R" }.join(" ")
  pages = texts.each_with_index.flat_map do |text, index|
    stream = "BT /F1 #{font_size} Tf #{at.join(" ")} Td (#{text}) Tj ET"
    [
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{size.join(" ")}] /Contents #{4 + index * 2} 0 R " \
        "/Resources << /Font << /F1 #{font_ref} 0 R >> >> >>",
      "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream"
    ]
  end
  objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [#{kids}] /Count #{texts.size} >>",
    *pages,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
  ]
  body = +"%PDF-1.4\n"
  offsets = objects.each_with_index.map do |object, index|
    offset = body.bytesize
    body << "#{index + 1} 0 obj\n#{object}\nendobj\n"
    offset
  end
  xref = body.bytesize
  body << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n"
  offsets.each { |offset| body << format("%010d 00000 n \n", offset) }
  body << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
end

write "sample.pdf", pdf("DevLibrary sample")

zip "sample.epub", {
  "mimetype" => "application/epub+zip",
  "META-INF/container.xml" => <<~XML,
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </container>
  XML
  "OEBPS/content.opf" => <<~XML,
    <?xml version="1.0" encoding="UTF-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier id="uid">urn:uuid:devlibrary-sample</dc:identifier>
        <dc:title>Café Noir</dc:title>
        <dc:creator>José Saramago</dc:creator>
        <dc:language>en</dc:language>
        <meta property="dcterms:modified">2026-10-14T00:00:00Z</meta>
      </metadata>
      <manifest>
        <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
        <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
      </manifest>
      <spine><itemref idref="ch1"/></spine>
    </package>
  XML
  "OEBPS/nav.xhtml" => <<~XML,
    <?xml version="1.0" encoding="UTF-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
      <head><title>Contents</title></head>
      <body><nav epub:type="toc"><ol><li><a href="chapter1.xhtml">Chapter 1</a></li></ol></nav></body>
    </html>
  XML
  "OEBPS/chapter1.xhtml" => <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head><title>Chapter 1</title></head>
      <body><h1>Chapter 1</h1><p>A reflowable sample chapter. ☕</p></body>
    </html>
  XML
}, stored_first: "mimetype"

zip "sample.cbz", { "001.png" => PNG, "002.png" => PNG }
zip "manga.cbz", { "001.png" => PNG, "002.png" => PNG, "003.png" => PNG }

write "sample.cbr", "Rar!\x1A\x07\x00".b + ("\0" * 64).b

# A DOCX-shaped archive wearing a .pdf name.
zip "fake.pdf", {
  "[Content_Types].xml" => %(<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>),
  "word/document.xml" => %(<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>)
}

write "cover.png", PNG
write "cover.jpg", JPEG
write "cover.webp", WEBP
write "cover.gif", GIF

# --- Multi-page reader fixtures (002 research R14): enough pages to turn, resume and zoom.

FileUtils.mkdir_p(File.join(OUT, "reader"))

# A solid-colour RGB PNG; comic pages only need to be told apart.
def png(width, height, rgb)
  chunk = ->(type, data) { [ data.bytesize ].pack("N") + type.b + data + [ Zlib.crc32(type.b + data) ].pack("N") }
  row = "\0".b + rgb.pack("C3") * width
  "\x89PNG\r\n\x1A\n".b +
    chunk.("IHDR", [ width, height, 8, 2, 0, 0, 0 ].pack("NNCCCCC")) +
    chunk.("IDAT", Zlib::Deflate.deflate(row * height, 9)) +
    chunk.("IEND", "".b)
end

write "reader/text-6-pages.pdf", pdf(*(1..6).map { |n| "Page #{n}" }, size: [ 400, 600 ], font_size: 64, at: [ 90, 300 ])

COMIC_COLOURS = [ [ 88, 101, 242 ], [ 236, 72, 189 ], [ 53, 237, 126 ], [ 0, 176, 244 ] ].freeze
MANGA_COLOURS = [ [ 30, 35, 83 ], [ 236, 120, 72 ], [ 160, 72, 236 ], [ 240, 200, 40 ] ].freeze

# Full-size covers in the brand colours, for seeds and cover-variant specs.
COMIC_COLOURS.each_with_index { |rgb, i| write "reader/cover-#{i + 1}.png", png(600, 900, rgb) }

zip "reader/comic-4-pages.cbz", COMIC_COLOURS.each_with_index.to_h { |rgb, i| [ format("%03d.png", i + 1), png(600, 900, rgb) ] }
zip "reader/manga-rtl-4-pages.cbz", MANGA_COLOURS.each_with_index.to_h { |rgb, i| [ format("%03d.png", i + 1), png(600, 900, rgb) ] }

WORDS = %w[the reader turned another page and the lantern light shivered across old shelves while
  rain kept time on the window every chapter carried a small promise of something waiting
  further along a quiet road through ink and paper toward morning].freeze

# About 1,500 deterministic words per chapter: several screens at both test viewports.
def chapter_paragraphs(seed)
  Array.new(15) do |p|
    words = Array.new(100) { |w| WORDS[(seed * 31 + p * 7 + w * 3) % WORDS.size] }
    "<p>#{words.join(" ").capitalize}.</p>"
  end.join("\n      ")
end

CHAPTERS = %w[One Two Three].freeze

zip "reader/reflowable-3-chapters.epub", {
  "mimetype" => "application/epub+zip",
  "META-INF/container.xml" => <<~XML,
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </container>
  XML
  "OEBPS/content.opf" => <<~XML,
    <?xml version="1.0" encoding="UTF-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier id="uid">urn:uuid:devlibrary-reader-epub</dc:identifier>
        <dc:title>Reader Test EPUB</dc:title>
        <dc:creator>DevLibrary</dc:creator>
        <dc:language>en</dc:language>
        <meta property="dcterms:modified">2026-10-20T00:00:00Z</meta>
      </metadata>
      <manifest>
        <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
        #{CHAPTERS.each_with_index.map { |_, i| %(<item id="ch#{i + 1}" href="chapter#{i + 1}.xhtml" media-type="application/xhtml+xml"/>) }.join("\n    ")}
      </manifest>
      <spine>#{CHAPTERS.each_index.map { |i| %(<itemref idref="ch#{i + 1}"/>) }.join}</spine>
    </package>
  XML
  "OEBPS/nav.xhtml" => <<~XML,
    <?xml version="1.0" encoding="UTF-8"?>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
      <head><title>Contents</title></head>
      <body><nav epub:type="toc"><ol>#{CHAPTERS.each_with_index.map { |name, i| %(<li><a href="chapter#{i + 1}.xhtml">Chapter #{name}</a></li>) }.join}</ol></nav></body>
    </html>
  XML
  **CHAPTERS.each_with_index.to_h { |name, i|
    [ "OEBPS/chapter#{i + 1}.xhtml", <<~XML ]
      <?xml version="1.0" encoding="UTF-8"?>
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Chapter #{name}</title></head>
        <body>
          <h1>Chapter #{name}</h1>
          #{chapter_paragraphs(i + 1)}
        </body>
      </html>
    XML
  }
}, stored_first: "mimetype"
