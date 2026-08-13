require_relative "boot"
require "active_record/railtie"
require "action_controller/railtie"
require "action_dispatch/railtie"

Bundler.require(*Rails.groups)

module AudioBunnyApi
  class Application < Rails::Application
    config.load_defaults 7.2

    # lib/jwt_service.rb isn't autoloadable otherwise — Rails 7.1+ no
    # longer adds lib/ to the autoload paths by default.
    config.autoload_lib(ignore: %w[])

    config.api_only = true
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc
  end
end
