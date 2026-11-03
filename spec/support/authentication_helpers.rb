module AuthenticationHelpers
  DEFAULT_PASSWORD = "password123".freeze

  module Request
    def sign_in_as(user, password: AuthenticationHelpers::DEFAULT_PASSWORD)
      post session_path, params: { email_address: user.email_address, password: password }
    end
  end

  module System
    def sign_in_as(user, password: AuthenticationHelpers::DEFAULT_PASSWORD, email: user.email_address)
      visit new_session_path
      fill_in "email_address", with: email
      fill_in "password", with: password
      click_button "Sign in"
    end

    # Signs in and waits until the signed-in page has loaded, so a following `visit` can't
    # cut the sign-in request short.
    def sign_in_and_wait_as(user, **options)
      sign_in_as(user, **options)
      expect(page).to have_css("button[aria-label='Account menu']")
    end
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers::Request, type: :request
  config.include AuthenticationHelpers::System, type: :system
end
