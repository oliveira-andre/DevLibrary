require "rails_helper"

RSpec.describe User::Lockable, type: :model do
  let(:start) { Time.zone.local(2026, 10, 14, 12, 0, 0) }
  let!(:user) { create(:user, email_address: "ana@example.com") }

  before { travel_to(start) }

  def fail_times(count)
    count.times { user.register_failed_sign_in! }
    user.reload
  end

  describe "#register_failed_sign_in!" do
    it "counts consecutive failures below the threshold" do
      fail_times(4)

      expect(user.failed_sign_in_attempts).to eq(4)
      expect(user).not_to be_locked
    end

    it "locks for 15 minutes on the fifth consecutive failure" do
      fail_times(5)

      expect(user).to be_locked
      expect(user.locked_until).to be_within(1.second).of(start + 15.minutes)
      expect(user.lockout_count).to eq(1)
      expect(user.failed_sign_in_attempts).to eq(0)
    end

    it "doubles the lock for every further lockout" do
      fail_times(5)

      travel_to(start + 16.minutes)
      fail_times(5)
      expect(user.locked_until).to be_within(1.second).of(start + 16.minutes + 30.minutes)

      travel_to(start + 47.minutes)
      fail_times(5)
      expect(user.locked_until).to be_within(1.second).of(start + 47.minutes + 60.minutes)
      expect(user.lockout_count).to eq(3)
    end

    it "caps the lock at 24 hours" do
      user.update_columns(lockout_count: 10)

      fail_times(5)

      expect(user.locked_until).to be_within(1.second).of(start + 24.hours)
    end

    it "leaves every counter unchanged while the account is locked" do
      fail_times(5)
      before = user.attributes.slice("failed_sign_in_attempts", "lockout_count", "locked_until")

      fail_times(3)

      expect(user.attributes.slice("failed_sign_in_attempts", "lockout_count", "locked_until")).to eq(before)
    end
  end

  describe "resetting" do
    before { fail_times(5) }

    it "clears everything on a successful sign-in" do
      user.register_successful_sign_in!
      user.reload

      expect(user).not_to be_locked
      expect(user.failed_sign_in_attempts).to eq(0)
      expect(user.lockout_count).to eq(0)
      expect(user.locked_until).to be_nil
    end

    it "clears everything when the password changes" do
      user.update!(password: "brand-new-pass", password_confirmation: "brand-new-pass")
      user.reload

      expect(user).not_to be_locked
      expect(user.failed_sign_in_attempts).to eq(0)
      expect(user.lockout_count).to eq(0)
    end
  end

  describe ".authenticate_with_lockout" do
    it "returns nil for an unknown email" do
      expect(User.authenticate_with_lockout(email_address: "nobody@example.com", password: "password123")).to be_nil
    end

    it "returns nil and counts the failure for a wrong password" do
      expect(User.authenticate_with_lockout(email_address: "ana@example.com", password: "wrong-password")).to be_nil
      expect(user.reload.failed_sign_in_attempts).to eq(1)
    end

    it "returns nil for a locked account even with the correct password" do
      fail_times(5)

      expect(User.authenticate_with_lockout(email_address: "ana@example.com", password: "password123")).to be_nil
    end

    it "still checks the password of a locked account so timing does not reveal the lock" do
      fail_times(5)
      allow(User).to receive(:find_by).and_return(user)
      expect(user).to receive(:authenticate).with("password123").and_call_original

      User.authenticate_with_lockout(email_address: "ana@example.com", password: "password123")
    end

    it "returns the user and resets failures on success, matching the email loosely" do
      fail_times(2)

      expect(User.authenticate_with_lockout(email_address: " ANA@Example.com ", password: "password123")).to eq(user)
      expect(user.reload.failed_sign_in_attempts).to eq(0)
    end
  end
end
