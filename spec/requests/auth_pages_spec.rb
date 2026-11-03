require "rails_helper"

# Sign-in and password pages share the branded auth card (002 US8, FR-043).
RSpec.describe "Auth pages", type: :request do
  def card
    response.parsed_body.at_css("main .auth-card")
  end

  it "shows sign-in in the card with its texts and links" do
    get new_session_path

    expect(card.at_css("img[alt='Dev Library']")).to be_present
    expect(card.at_css("h1").text).to eq("Welcome back")
    expect(card.at_css("a[href='#{new_password_path}']").text).to eq("Forgot password?")
    expect(card.at_css("a[href='#{new_registration_path}']").text).to eq("Create an account")
    expect(response.parsed_body.at_css(".nav")).to be_nil
  end

  it "sends a signed-in person from sign-in to home" do
    sign_in_as(create(:user))

    get new_session_path

    expect(response).to redirect_to(root_path)
  end

  it "shows the sign-in alert inside the card" do
    post session_path, params: { email_address: "nobody@example.com", password: "nope-nope" }
    follow_redirect!

    expect(card.at_css("[role=alert]").text.strip).to eq("Try another email address or password.")
  end

  it "shows forgot password in the card" do
    get new_password_path

    expect(card.at_css("img[alt='Dev Library']")).to be_present
    expect(card.at_css("h1").text).to eq("Forgot your password?")
    expect(card.at_css("a[href='#{new_session_path}']").text).to eq("Back to sign in")
  end

  it "shows reset password in the card" do
    get edit_password_path(create(:user).password_reset_token)

    expect(card.at_css("img[alt='Dev Library']")).to be_present
    expect(card.at_css("h1").text).to eq("Choose a new password")
    expect(card.at_css("a[href='#{new_session_path}']").text).to eq("Back to sign in")
  end
end
