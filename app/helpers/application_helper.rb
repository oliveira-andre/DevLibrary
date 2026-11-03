module ApplicationHelper
  # Shared tokens and components (constitution Principle IV), linked by every layout. Turbo
  # tracks them, so a deploy that changes them reloads the page; the list must be the same
  # in every layout or Turbo would reload on every move between layouts.
  SHARED_STYLESHEETS = %w[
    shared/tokens shared/fonts shared/base shared/buttons shared/cards shared/forms
    shared/nav shared/modal actiontext
  ].freeze

  def shared_stylesheet_tags
    stylesheet_link_tag(*SHARED_STYLESHEETS, "data-turbo-track": "reload")
  end

  # Page-scoped styles come and go with the page (Turbo "dynamic" tracking).
  def page_stylesheet(*names)
    content_for :stylesheets, stylesheet_link_tag(*names, "data-turbo-track": "dynamic")
  end
end
