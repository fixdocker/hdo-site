require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"
require "sprockets/railtie"

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

I18n.enforce_available_locales = true

module Hdo
  class Application < Rails::Application
    config.before_configuration do
      env = Rails.root.join('config/env.yml')

      if env.exist?
        YAML.load(env.read).each { |k, v| ENV[k.to_s] = v.to_s }
      end
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib #{config.root}/app/models/concerns)

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
    config.i18n.default_locale = :nb

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    config.lograge.custom_options = lambda do |event|
      {:time => event.time.iso8601}
    end

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = true

    # Enable the asset pipeline
    config.assets.enabled = true
    config.assets.paths << "#{Rails.root}/app/assets/fonts"

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.1'

    # this is needed on heroku: https://github.com/plataformatec/devise/issues/1339
    config.assets.initialize_on_precompile = false

    # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
    config.assets.precompile += %w[
      conditional/html5.js
      conditional/respond.js
      conditional/spring.js
      conditional/json2.js
      widgets/widgets.css
      widgets/frame.js
      widgets/widgets.js
      .svg
    ]

    # allow cors from other subdomains
    config.middleware.use ::Rack::Cors do
      allow do
        origins(/holderdeord\.no$/)
        resource '*', :headers => :any, :methods => [:get, :options]
      end
    end

    # # This is turned off until we figure out how to deal with caching.
    # config.middleware.use 'Hdo::Rack::Locale'

    # we rely on fastly + instant purges
    config.middleware.delete 'Rack::Cache'
    config.middleware.insert_after ActiveRecord::QueryCache, 'Hdo::Rack::Fastly'
  end
end
