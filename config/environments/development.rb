Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  config.active_job.queue_adapter = ENV.fetch('QUEUE_ADAPTER', :inline)

  config.sso_cookie_name = ENV.fetch('SSO_COOKIE_NAME', 'flight_sso_dev')
  config.sso_domain = "alces-flight.lvh.me"
  config.sso_uri = "http://accounts.alces-flight.lvh.me:4000"
  config.use_ssl = false

  config.default_url_options = {
    host: "control.alces-flight.lvh.me",
    port: ENV.fetch('PORT', 3000),
  }
  config.hosts << "control.alces-flight.lvh.me"

  config.slack_token = ENV["SLACK_TOKEN"]
  config.usd_gbp_conversion = ENV["USD_GBP_CONVERSION"].to_f
  config.gbp_compute_conversion = ENV["GBP_COMPUTE_CONVERSION"].to_f
  config.at_risk_conversion = ENV["AT_RISK_CONVERSION"].to_f
end
