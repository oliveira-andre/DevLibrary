# Per-account lockout that holds no matter how many IPs the guesses come from.
# 5 consecutive failures lock the account for 15 min × 2^(previous lockouts), up to 24 h.
# A successful sign-in or a password change clears it. See research R6.
module User::Lockable
  extend ActiveSupport::Concern

  MAX_FAILED_ATTEMPTS = 5
  BASE_LOCK = 15.minutes
  MAX_LOCK = 24.hours

  included do
    after_update :clear_sign_in_lockout!, if: :saved_change_to_password_digest?
  end

  class_methods do
    # Returns the user on success, nil otherwise. Unknown, wrong and locked all look the same.
    def authenticate_with_lockout(email_address:, password:)
      user = find_by(email_address: email_address)
      return authenticate_by(email_address: email_address, password: password) unless user

      if user.locked?
        user.authenticate(password) # keep timing identical; result is ignored
        return nil
      end

      if user.authenticate(password)
        user.register_successful_sign_in!
        user
      else
        user.register_failed_sign_in!
        nil
      end
    end
  end

  def locked?
    locked_until.present? && locked_until.future?
  end

  def register_failed_sign_in!
    with_lock do
      next if locked?

      attempts = failed_sign_in_attempts + 1
      if attempts >= MAX_FAILED_ATTEMPTS
        update_columns(failed_sign_in_attempts: 0, lockout_count: lockout_count + 1, locked_until: Time.current + lock_duration)
      else
        update_columns(failed_sign_in_attempts: attempts)
      end
    end
  end

  def register_successful_sign_in!
    clear_sign_in_lockout! if failed_sign_in_attempts.positive? || lockout_count.positive? || locked_until
  end

  def clear_sign_in_lockout!
    update_columns(failed_sign_in_attempts: 0, lockout_count: 0, locked_until: nil)
  end

  private
    def lock_duration
      [ BASE_LOCK * (2**lockout_count), MAX_LOCK ].min
    end
end
