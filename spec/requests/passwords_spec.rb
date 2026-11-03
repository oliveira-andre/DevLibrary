require "rails_helper"

RSpec.describe "Passwords", type: :request do
  let(:user) { create(:user, locked_until: 10.minutes.from_now, lockout_count: 2) }
  let(:token) { user.password_reset_token }

  it "resets the password and lifts the lock" do
    put password_path(token), params: { password: "brand-new-pass", password_confirmation: "brand-new-pass" }

    expect(response).to redirect_to(new_session_path)
    expect(flash[:notice]).to eq("Password has been reset.")
    expect(user.reload).not_to be_locked
    expect(user.lockout_count).to eq(0)
  end

  it "shows the real validation error for a too-short password" do
    put password_path(token), params: { password: "short", password_confirmation: "short" }

    expect(response).to redirect_to(edit_password_path(token))
    expect(flash[:alert]).to include("Password is too short (minimum is 8 characters)")
  end
end
