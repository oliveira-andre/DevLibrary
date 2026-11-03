# Inline Lucide icons (ISC licence, app/assets/images/icons/LICENSE). Inline SVG takes
# currentColor and needs no extra request. Icons are decorative unless given a title.
module IconsHelper
  ICONS = Rails.root.glob("app/assets/images/icons/*.svg").to_h do |path|
    [ path.basename(".svg").to_s, path.read[%r{<svg[^>]*>(.*)</svg>}m, 1].strip ]
  end.freeze

  def icon(name, title: nil, **attributes)
    paths = ICONS.fetch(name.to_s) { raise ArgumentError, "unknown icon #{name.inspect}" }
    label = title ? { role: "img", "aria-label": title } : { "aria-hidden": "true" }
    css_class = [ "icon", attributes.delete(:class) ]

    tag.svg(paths.html_safe,
      xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
      "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round", focusable: "false",
      class: css_class, **label, **attributes)
  end
end
