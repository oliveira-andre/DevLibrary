require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DevLibrary
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Active Storage redirect/proxy URLs never expire by default. Book files must not
    # have permanent links (constitution Principle VIII, FR-052).
    config.active_storage.urls_expire_in = 1.hour

    # Forms mark invalid fields themselves (.field--invalid, aria-invalid in shared/forms.css)
    # instead of Rails wrapping them in an extra div that breaks the field layout.
    config.action_view.field_error_proc = ->(html_tag, _instance) { html_tag }
  end
end
