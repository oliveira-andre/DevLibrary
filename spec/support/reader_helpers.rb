# Drives the reader in system specs (002 research R14). Assertions read the reader's
# data-reader-* attributes (contracts/reader-client.md §7), never pixels.
module ReaderHelpers
  def wait_for_reader(state: "ready")
    expect(page).to have_css("#reader[data-reader-state='#{state}']", wait: 15)
  end

  def reader_location
    find("#reader")["data-reader-location"]
  end

  def reader_progress
    find("#reader")["data-reader-progress"].to_f
  end

  # Key presses through Chrome's input pipeline (CDP), as trusted events to the focused element.
  # Selenium's send_keys drops repeated presses on the same element under Chrome 155.
  KEYS = {
    page_down: [ "PageDown", 34 ], page_up: [ "PageUp", 33 ],
    arrow_left: [ "ArrowLeft", 37 ], arrow_right: [ "ArrowRight", 39 ], space: [ " ", 32 ]
  }.freeze

  def press_reader_key(name)
    key, code = KEYS.fetch(name)
    reader_surface.execute_script("if (!this.contains(document.activeElement)) this.focus()")
    %w[rawKeyDown keyUp].each do |type|
      page.driver.browser.execute_cdp("Input.dispatchKeyEvent", type: type, key: key,
        code: key == " " ? "Space" : key, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code)
    end
  end

  # Turns one page and, unless told otherwise, waits until the reader has settled on a new
  # location. `via:` picks the input: keyboard, a tap on the page edge, or a touch swipe.
  def turn_page(direction = :next, via: :key, expect_change: true)
    before = reader_location
    case via
    when :key then press_reader_key(direction == :next ? :page_down : :page_up)
    when :tap then tap_reader_edge(visual_side(direction))
    when :swipe then swipe_reader(direction)
    end
    if expect_change
      expect(page).to have_css("#reader[data-reader-state='ready']:not([data-reader-location='#{before}'])", wait: 10)
    end
  end

  # Taps the outer edge of the page (the 30% tap zones): :left or :right, as seen on screen.
  def tap_reader_edge(side)
    rect = element_rect(reader_surface)
    x = side == :left ? rect["width"] * 0.1 : rect["width"] * 0.9
    reader_surface.click(x: (x - rect["width"] / 2).round, y: 0)
  end

  # A touch swipe across the middle of the page, in the direction that turns the page.
  def swipe_reader(direction)
    rect = element_rect(reader_surface)
    y = rect["top"] + rect["height"] / 2
    from, to = rect["left"] + rect["width"] * 0.8, rect["left"] + rect["width"] * 0.2
    from, to = to, from if visual_side(direction) == :left
    touch_swipe(from: [ from, y ], to: [ to, y ])
  end

# A one-finger swipe through Chrome's input pipeline (CDP), so the browser treats it as real
  # touch: native scrolling happens and pages see touch and pointer events. Selenium's W3C
  # touch actions stall under mobile emulation, so they aren't used.
  def touch_swipe(from:, to:, steps: 10)
    browser = page.driver.browser
    touch = ->(type, x = nil, y = nil) do
      points = x ? [ { x: x.round, y: y.round } ] : []
      browser.execute_cdp("Input.dispatchTouchEvent", type: type, touchPoints: points)
    end

    touch.("touchStart", *from)
    1.upto(steps) do |step|
      fraction = step / steps.to_f
      touch.("touchMove", from[0] + (to[0] - from[0]) * fraction, from[1] + (to[1] - from[1]) * fraction)
    end
    touch.("touchEnd")
  end

# A two-finger pinch around the middle of the page, spreading the fingers apart by `spread` px.
  def pinch_reader(spread: 160, steps: 10)
    rect = element_rect(reader_surface)
    cx, cy = rect["left"] + rect["width"] / 2, rect["top"] + rect["height"] / 2
    browser = page.driver.browser
    fingers = ->(gap) { [ { x: (cx - gap).round, y: cy.round, id: 0 }, { x: (cx + gap).round, y: cy.round, id: 1 } ] }

    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: fingers.(30))
    1.upto(steps) do |step|
      browser.execute_cdp("Input.dispatchTouchEvent", type: "touchMove", touchPoints: fingers.(30 + spread / 2.0 * step / steps))
    end
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
  end

  def go_offline
    page.driver.browser.network_conditions = { offline: true, latency: 0, throughput: 0 }
  end

  def go_online
    page.driver.browser.network_conditions = { offline: false, latency: 0, throughput: -1 }
  end

  def emulate_reduced_motion
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
  end

  private
    def reader_surface
      find("#reader .reader-surface")
    end

    # "Next" is on the right for left-to-right books and on the left for right-to-left ones.
    def visual_side(direction)
      rtl = find("#reader_preferences", visible: :all)["data-reader-preferences-direction-value"] == "rtl"
      forward = direction == :next
      forward ^ rtl ? :right : :left
    end

    def element_rect(element)
      page.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", element)
    end
end

RSpec.configure do |config|
  config.include ReaderHelpers, type: :system

  # An example that goes offline or asks for reduced motion must not leave the shared browser
  # that way for the next one.
  config.after(:each, type: :system) do
    go_online
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  rescue StandardError
    nil
  end
end
