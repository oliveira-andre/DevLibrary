#!/usr/bin/env ruby
# Derives every brand asset from the four logo sources in app/assets/images/ (research R16,
# R17): the header and sign-in wordmarks, the favicon set, the home-screen icons and the
# 1200×630 link-preview image. The sources are large and padded, so pages only use these
# outputs. Re-run it whenever a source logo changes; the outputs are committed.
#
#   bundle exec ruby script/generate_brand_assets.rb

require "bundler/setup"
require "fileutils"
require "vips"

ROOT = File.expand_path("..", __dir__)
SOURCES = File.join(ROOT, "app/assets/images")
BRAND = File.join(SOURCES, "brand")
PUBLIC = File.join(ROOT, "public")
FileUtils.mkdir_p(BRAND)

def source(name)
  Vips::Image.new_from_file(File.join(SOURCES, name))
end

# Crops the transparent padding around a logo (alpha above a faint threshold).
def trim(image)
  left, top, width, height = image.extract_band(3).find_trim(background: [ 0 ], threshold: 10)
  image.crop(left, top, width, height)
end

def to_height(image, height)
  image.resize(height.to_f / image.height)
end

def to_size(image, side)
  image.resize(side.to_f / image.width)
end

# Centres the image on a transparent square, with `padding` as a fraction of the longer side.
def square(image, padding:)
  side = ([ image.width, image.height ].max * (1 + padding * 2)).round
  image.gravity(:centre, side, side, extend: :background, background: [ 0, 0, 0, 0 ])
end

# PNGs are palette-quantized: WhatsApp drops preview images over ~300 KB, and icons load
# on every page.
def write(image, path, **options)
  options = { palette: true, compression: 9 }.merge(options) if path.end_with?(".png")
  image.write_to_file(path, **options)
  puts "wrote #{path.delete_prefix("#{ROOT}/")} (#{image.width}×#{image.height})"
end

# An .ico is a small directory of embedded PNGs; vips cannot write the container itself.
def write_ico(path, images)
  pngs = images.map { |image| image.write_to_buffer(".png") }
  offset = 6 + 16 * pngs.size
  entries = images.zip(pngs).map do |image, png|
    entry = [ image.width % 256, image.height % 256, 0, 0, 1, 32, png.bytesize, offset ].pack("CCCCvvVV")
    offset += png.bytesize
    entry
  end
  File.binwrite(path, [ 0, 1, pngs.size ].pack("vvv") + entries.join + pngs.join)
  puts "wrote #{path.delete_prefix("#{ROOT}/")} (#{images.map(&:width).join(", ")})"
end

wordmark = trim(source("logo_with_text.png"))
mark = square(trim(source("logo_without_text.png")), padding: 0.06)
mark_on_background = source("logo_without_text_with_bg.png")
wordmark_on_background = source("logo_with_text_with_bg.png")
background = wordmark_on_background.getpoint(2, 2).map(&:round)

# Header (shown at 32 CSS px) and sign-in card (80 CSS px), both at 2× density.
[ 64, 160 ].each do |height|
  image = to_height(wordmark, height)
  write(image, File.join(BRAND, "wordmark-#{height}.webp"), Q: 90)
  write(image, File.join(BRAND, "wordmark-#{height}.png"))
end

write_ico(File.join(PUBLIC, "favicon.ico"), [ to_size(mark, 16), to_size(mark, 32) ])
write(to_size(mark, 512), File.join(PUBLIC, "icon.png"))
write(to_size(mark, 192), File.join(PUBLIC, "icon-192.png"))

# Home-screen icons are opaque, so iOS and Android never draw their own backdrop.
write(to_size(mark_on_background, 180), File.join(PUBLIC, "apple-touch-icon.png"))
write(to_size(mark_on_background, 512), File.join(PUBLIC, "icon-maskable.png"))

og = to_height(wordmark_on_background, 630).gravity(:centre, 1200, 630, extend: :background, background: background)
write(og, File.join(PUBLIC, "og-image.png"))

FileUtils.rm_f(File.join(PUBLIC, "icon.svg"))
puts "removed public/icon.svg (default red circle)"
puts "brand background: #%02x%02x%02x" % background
