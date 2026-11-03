# Book covers (the request's "cape"). Missing covers show a title placeholder (FR-005).
module CoversHelper
  # CSS size of each variant; the files are twice as large for 2× screens (data-model.md).
  DISPLAY_SIZES = { card: [ 240, 360 ], large: [ 300, 450 ] }.freeze

  def cover_image_tag(book, variant: :card, **options)
    return render("shared/cover_placeholder", title: book.title) unless book.cover.attached?

    width, height = DISPLAY_SIZES.fetch(variant)
    image_tag cover_url(book, variant), alt: book.title, width: width, height: height,
      loading: "lazy", decoding: "async", class: [ "cover", options.delete(:class) ], **options
  end

  # Active Storage URLs expire (config.active_storage.urls_expire_in). Signing with an
  # expiry rounded to the hour keeps the same URL for an hour, so the browser cache can
  # reuse the image instead of refetching it on every page (research R13).
  def cover_url(book, variant)
    rails_storage_redirect_path(book.cover.variant(variant), expires_at: Time.current.beginning_of_hour + 2.hours)
  end
end
