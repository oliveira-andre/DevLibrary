# System specs run on a mobile screen first, then desktop (constitution Principle III).
#
#   on_each_viewport do
#     it "signs in" do ... end
#   end
#
# defines the examples twice: "on mobile" (390×844) and "on desktop" (1440×900).
#
# Every example shares one Chrome. Mobile examples switch it into device emulation through
# DevTools (touch screen, coarse pointer, 3× density, mobile user agent) so specs can swipe and
# pinch; desktop examples switch it back. A second browser for mobile would sit next to the
# desktop one, and Chrome then treats one as occluded and drops its key presses and frames.
module SystemViewports
  SIZES = { mobile: [ 390, 844 ], desktop: [ 1440, 900 ] }.freeze
  MOBILE_USER_AGENT = "Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 " \
                      "(KHTML, like Gecko) Chrome/155.0.0.0 Mobile Safari/537.36".freeze

  module ClassMethods
    def on_each_viewport(&block)
      SIZES.each_key do |viewport|
        context("on #{viewport}", viewport: viewport, &block)
      end
    end
  end

  # For the few steps that differ by device, e.g. swipe on mobile, click on desktop.
  def mobile_viewport?
    RSpec.current_example.metadata[:viewport] == :mobile
  end

  def emulate_viewport(viewport)
    browser = page.driver.browser
    if viewport == :mobile
      width, height = SIZES[:mobile]
      browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 3, mobile: true)
      browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 5)
      browser.execute_cdp("Emulation.setUserAgentOverride", userAgent: MOBILE_USER_AGENT)
    else
      browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
      browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
      browser.execute_cdp("Emulation.setUserAgentOverride", userAgent: browser.execute_cdp("Browser.getVersion")["userAgent"])
    end
  end
end

RSpec.configure do |config|
  config.extend SystemViewports::ClassMethods, type: :system
  config.include SystemViewports, type: :system

  config.before(:each, type: :system) do |example|
    driven_by :selenium, using: :headless_chrome, screen_size: SystemViewports::SIZES[:desktop] do |options|
      options.add_option("goog:loggingPrefs", { browser: "ALL" })
      options.add_argument("--disable-backgrounding-occluded-windows")
      options.add_argument("--disable-renderer-backgrounding")
      options.add_argument("--disable-background-timer-throttling")
      # Specs sign in with "password123", a known-breached password. Chrome's password manager
      # then raises its save / leaked-password bubble, which takes the tab's input, so later
      # clicks and key presses never reach the page. A test browser needs neither.
      options.add_preference(:credentials_enable_service, false)
      options.add_preference(:profile, password_manager_enabled: false, password_manager_leak_detection: false)
      options.add_argument("--disable-features=PasswordLeakDetection")
    end
    emulate_viewport(example.metadata[:viewport] || :desktop)
  end

  # A failing example prints what the browser said, which usually explains it.
  config.after(:each, type: :system) do |example|
    next unless example.exception

    messages = page.driver.browser.logs.get(:browser).map { |entry| "[#{entry.level}] #{entry.message}" }
    warn "\nBrowser console for #{example.full_description}:\n  #{messages.last(20).join("\n  ")}" if messages.any?
  rescue StandardError
    nil # the browser may already be gone
  end
end
