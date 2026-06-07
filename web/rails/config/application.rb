require_relative "boot"
require "active_record/railtie"
require "action_controller/railtie"
require "action_dispatch/railtie"

Bundler.require(*Rails.groups)

module AudioBunnyApi
  class Application < Rails::Application
    config.load_defaults 7.2
    config.api_only = true
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc
  end
end
