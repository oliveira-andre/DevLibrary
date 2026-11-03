# Icon-only controls (scroll arrows, heart, reader toolbar) are named by aria-label, so let
# click_button / click_link / fill_in find them the way assistive technology does.
Capybara.enable_aria_label = true

# Segmented choices (reader theme) hide the radio and style its label, as people tap the label.
Capybara.automatic_label_click = true

# Readers load engines and render pages asynchronously; give the browser time under load.
Capybara.default_max_wait_time = 5
