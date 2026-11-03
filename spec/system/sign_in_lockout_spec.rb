require "rails_helper"

RSpec.describe "Sign-in lockout", type: :system do
  let(:generic_alert) { "Try another email address or password." }

  on_each_viewport do
    let!(:user) { create(:user, email_address: "user@example.com") }

    it "refuses the correct password after five wrong ones, with the same message every time" do
      5.times do
        sign_in_as(user, password: "wrong-password")
        expect(page).to have_text(generic_alert)
      end

      sign_in_as(user)

      expect(page).to have_text(generic_alert)
      expect(page).to have_current_path(new_session_path)
    end

    it "signs in with a differently-cased email" do
      sign_in_as(user, email: "USER@Example.com")

      expect(page).to have_current_path(home_path)
      expect(page).not_to have_text(generic_alert)
    end
  end
end
