#!/usr/bin/env ruby
# Writes a ~500 MB, 400-page PDF for checking that the reader opens a large book on its
# saved page without downloading the whole file (002 spec SC-005, research R6). Each page
# embeds an uncompressible random-noise image, so the size is real. The output is never
# committed: write it under tmp/. Streams to disk; nothing is held in memory.
#
#   ruby script/generate_large_pdf.rb tmp/large.pdf

path = ARGV.fetch(0) { abort "usage: ruby script/generate_large_pdf.rb PATH" }
PAGES = 400
WIDTH = 640
HEIGHT = 650 # 640 × 650 × 3 bytes ≈ 1.25 MB per page

# Objects: 1 catalog, 2 page tree, 3 font, then per page: page, content stream, image.
page_ref = ->(index) { 4 + index * 3 }
offsets = []

File.open(path, "wb") do |file|
  write_object = lambda do |number, body|
    offsets[number] = file.pos
    file.write("#{number} 0 obj\n")
    body.respond_to?(:call) ? body.call : file.write(body)
    file.write("\nendobj\n")
  end

  file.write("%PDF-1.4\n%\xE2\xE3\xCF\xD3\n".b)
  write_object.(1, "<< /Type /Catalog /Pages 2 0 R >>")
  kids = Array.new(PAGES) { |index| "#{page_ref.(index)} 0 R" }.join(" ")
  write_object.(2, "<< /Type /Pages /Kids [#{kids}] /Count #{PAGES} >>")
  write_object.(3, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")

  PAGES.times do |index|
    page, content, image = page_ref.(index), page_ref.(index) + 1, page_ref.(index) + 2
    write_object.(page, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 600] /Contents #{content} 0 R " \
                        "/Resources << /Font << /F1 3 0 R >> /XObject << /Im1 #{image} 0 R >> >> >>")
    stream = "q 400 0 0 600 0 0 cm /Im1 Do Q BT /F1 48 Tf 1 1 1 rg 100 280 Td (Page #{index + 1}) Tj ET"
    write_object.(content, "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream")
    length = WIDTH * HEIGHT * 3
    write_object.(image, lambda {
      file.write("<< /Type /XObject /Subtype /Image /Width #{WIDTH} /Height #{HEIGHT} " \
                 "/ColorSpace /DeviceRGB /BitsPerComponent 8 /Length #{length} >>\nstream\n")
      file.write(Random.bytes(length))
      file.write("\nendstream")
    })
    print "\rpage #{index + 1}/#{PAGES}" if ((index + 1) % 20).zero?
  end

  xref = file.pos
  file.write("xref\n0 #{offsets.size}\n0000000000 65535 f \n")
  offsets.drop(1).each { |offset| file.write(format("%010d 00000 n \n", offset)) }
  file.write("trailer\n<< /Size #{offsets.size} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n")
end

puts "\nwrote #{path} (#{(File.size(path) / 1024.0 / 1024).round} MB)"
