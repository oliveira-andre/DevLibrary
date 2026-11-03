# Every Active Storage route (blob redirects, proxies, representations, direct uploads)
# requires a signed-in session, so a leaked file URL is useless without an account
# (constitution Principle VIII, FR-052).
Rails.application.config.to_prepare do
  ActiveStorage::BaseController.include Authentication
end
