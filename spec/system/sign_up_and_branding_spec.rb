require "rails_helper"

RSpec.describe "Sign-up and branded auth pages", type: :system do
  on_each_viewport do
    it "shows the wordmark and a way to create an account on sign-in" do
      visit new_session_path

      within(".auth-card") do
        expect(page).to have_css("img[alt='Dev Library']")
        expect(page).to have_css("h1", text: /Welcome back/i)
        expect(page).to have_link("Create an account")
        expect(page).to have_link("Forgot password?")
      end
    end

    it "signs up as Ana and lands on home, signed in" do
      visit new_session_path
      click_link "Create an account"

      fill_in "Name", with: "Ana"
      fill_in "Email", with: "Ana@Example.COM"
      fill_in "Password", with: "password123"
      fill_in "Confirm password", with: "password123"
      click_button "Create account"

      # The account menu only exists when signed in; its name label is hidden on phones.
      expect(page).to have_css("button[aria-label='Account menu']")
      expect(page).to have_current_path(home_path)
      expect(User.find_by(email_address: "ana@example.com")).to have_attributes(name: "Ana", role: "reader")
    end

    it "keeps what was typed when the name is missing" do
      visit new_registration_path

      fill_in "Email", with: "ana@example.com"
      fill_in "Password", with: "password123"
      fill_in "Confirm password", with: "password123"
      page.execute_script("document.getElementById('user_name').removeAttribute('required')")
      click_button "Create account"

      expect(page).to have_text("Name can't be blank")
      expect(page).to have_field("Email", with: "ana@example.com")
      expect(page).to have_field("Password", with: "")
    end

    it "brands the forgot-password and reset-password pages" do
      visit new_session_path
      click_link "Forgot password?"

      expect(page).to have_css(".auth-card img[alt='Dev Library']")
      expect(page).to have_css("h1", text: /Forgot your password\?/i)

      visit edit_password_path(create(:user).password_reset_token)

      expect(page).to have_css(".auth-card img[alt='Dev Library']")
      expect(page).to have_css("h1", text: /Choose a new password/i)
      click_link "Back to sign in"
      expect(page).to have_css("h1", text: /Welcome back/i)
    end

    it "sends a signed-in person from sign-in and sign-up to home, where the wordmark links home" do
      sign_in_and_wait_as(create(:user))

      visit new_session_path
      expect(page).to have_current_path(home_path).or have_current_path(root_path)
      visit new_registration_path
      expect(page).to have_current_path(home_path).or have_current_path(root_path)

      expect(page).to have_css(".nav a[href='#{home_path}'] img[alt='Dev Library']")
    end
  end
end
