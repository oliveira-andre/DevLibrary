# Contract: Sign-in, Password Reset and File Access

**Covers**: FR-001, FR-002, FR-007–FR-011, FR-052 · **Research**: R3, R6

These are the only HTTP behaviors this feature changes. Everything else is the
model-level contract in [domain-api.md](domain-api.md).

## `POST /session` (SessionsController#create)

**Params**: `email_address`, `password`

| Condition | Response | Side effects |
|---|---|---|
| More than 10 requests from one IP in 3 min (existing `rate_limit`) | `302 → /session/new`, alert `"Try again later."` | none |
| Email unknown (after trim + downcase) | `302 → /session/new`, alert `"Try another email address or password."` | none (constant-time digest via `authenticate_by`) |
| Account locked (`locked_until > now`), any password | **same as above** | password still checked and result discarded (timing parity). Counters unchanged |
| Wrong password, account not locked | **same as above** | `failed_sign_in_attempts += 1`. On reaching 5: lock for `min(15 min × 2^lockout_count, 24 h)`, `lockout_count += 1`, attempts reset to 0 |
| Correct password, not locked | `302 → after_authentication_url` | session created. Attempts, lockout count and lock cleared |

**Invariants**
- The three failure rows produce byte-identical responses (status, location, flash).
- `" ANA@Example.com "` and `"ana@example.com"` resolve to the same account.
- 5 consecutive failures from 5 different IPs lock the account. IP diversity does not
  reset or avoid the counter.

**Home route**: `GET /home` (`home_url`) and `GET /` both render `HomeController#show`, the
future catalog search page. It is blank for now and requires a session through
`ApplicationController`, so signed-out visitors are sent to sign-in.
`after_authentication_url` falls back to `home_url`.

## `PATCH/PUT /passwords/:token` (PasswordsController#update)

| Condition | Response | Side effects |
|---|---|---|
| Valid token, valid new password (8–72, confirmed) | `302 → /session/new`, notice `"Password has been reset."` (existing) | password changed, all sessions destroyed (existing), **lockout cleared** (model callback, FR-010) |
| Valid token, invalid password | `302 → /passwords/:token/edit`, alert = first validation error message (replaces the fixed "Passwords did not match.", which is wrong now that length is validated) | none |

## Active Storage routes (`/rails/active_storage/*`)

| Condition | Response |
|---|---|
| No session | `302 → /session/new` |
| Signed in | existing behavior. Generated URLs expire after `urls_expire_in` (1 hour) |

Book files and conversion outputs are linked to readers only through future authorized
download endpoints (FR-052). This guard ensures no Active Storage URL works without a
session.

## Required tests

- `spec/requests/sessions_spec.rb`: each table row; identical failure responses; mixed-case
  email; lock after 5 failures from rotating `REMOTE_ADDR`; lock expiry with `travel_to`;
  doubling and cap.
- `spec/requests/passwords_spec.rb`: reset clears the lock; a short password shows the
  length error.
- `spec/requests/active_storage_access_spec.rb`: anonymous blob redirect → sign-in;
  signed-in access works.
- `spec/system/sign_in_lockout_spec.rb`: mobile viewport (390×844) first, then desktop
  (1440×900). Five wrong passwords, then the correct one is refused with the generic alert.
