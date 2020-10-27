require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'syslog/logger'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

begin
  Dotenv.load! File.expand_path("../../.env", __FILE__)
rescue Errno::ENOENT
  $stderr.puts "Please create .env file, e.g. from .env.example"
  exit
end

module Lagotto
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)
    config.autoload_paths += Dir["#{config.root}/app/models/**/**", "#{config.root}/app/controllers/**/"]

    # add assets from Ember app
    config.assets.paths << "#{Rails.root}/frontend/bower_components"

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    # TODO: do I need to add salt here?
    config.filter_parameters += [:password, :authentication_token]

    # Use a different cache store
    # dalli uses ENV['MEMCACHE_SERVERS']
    ENV['MEMCACHE_SERVERS'] ||= ENV['HOSTNAME']
    config.cache_store = :dalli_store, nil, { :namespace => ENV['APPLICATION'], :compress => true }

    # Skip validation of locale
    I18n.enforce_available_locales = false

    # Disable IP spoofing check
    config.action_dispatch.ip_spoofing_check = false

    # compress responses with deflate or gzip
    config.middleware.use Rack::Deflater

    # set Active Job queueing backend
    config.active_job.queue_adapter = :sidekiq

    # Minimum Sass number precision required by bootstrap-sass
    #::Sass::Script::Value::Number.precision = [8, ::Sass::Script::Value::Number.precision].max

    # parameter keys that are not explicitly permitted will raise error
    config.action_controller.action_on_unpermitted_parameters = :raise
  end
end
