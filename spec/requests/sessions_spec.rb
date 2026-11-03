require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) { create(:user, email_address: "ana@example.com") }
  let(:generic_alert) { "Try another email address or password." }

  def attempt(email: "ana@example.com", password: "wrong-password", ip: "10.0.0.1")
    post session_path, params: { email_address: email, password: password }, env: { "REMOTE_ADDR" => ip }
    [ response.status, response.location, flash[:alert] ]
  end

  it "signs in with the correct password, matching the email loosely" do
    expect { attempt(email: "  ANA@example.com ", password: "password123") }
      .to change { user.sessions.count }.by(1)

    expect(response).to redirect_to(home_url)
  end

  it "gives identical responses for an unknown email, a wrong password and a locked account" do
    unknown = attempt(email: "nobody@example.com")
    wrong = attempt
    user.update_columns(locked_until: 10.minutes.from_now, lockout_count: 1)
    locked = attempt(password: "password123")

    expect([ wrong, locked ]).to all(eq(unknown))
    expect(unknown).to eq([ 302, new_session_url, generic_alert ])
  end

  it "locks the account after five failures even when every attempt uses a different IP" do
    5.times { |n| attempt(ip: "203.0.113.#{n + 1}") }

    expect(user.reload).to be_locked

    expect { attempt(password: "password123", ip: "198.51.100.7") }.not_to change { user.sessions.count }
    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq(generic_alert)
  end

  it "keeps the per-IP rate limit" do
    allow(SessionsController.cache_store).to receive(:increment).and_return(11)

    attempt(password: "password123")

    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to eq("Try again later.")
  end
end
