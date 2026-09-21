# frozen_string_literal: true

require "ferrum"
require "tempfile"
require "base64"

class FerrumPdfGenerator
  DEFAULT_TIMEOUT = 60
  DEFAULT_PROCESS_TIMEOUT = 60
  DEFAULT_WINDOW_SIZE = [ 1200, 1600 ].freeze

  DEFAULT_BROWSER_OPTIONS = {
    "no-sandbox" => nil,
    "disable-gpu" => nil,
    "disable-dev-shm-usage" => nil,
    "no-zygote" => nil,
    "disable-software-rasterizer" => nil,
    "disable-setuid-sandbox" => nil,
    "disable-extensions" => nil,
    "disable-background-networking" => nil,
    "disable-default-apps" => nil,
    "disable-sync" => nil,
    "mute-audio" => nil,
    "no-first-run" => nil,
    "disable-features" => "AudioServiceOutOfProcess,IsolateOrigins,site-per-process"
  }.freeze

  # Renders HTML content into a binary PDF string using an isolated Ferrum browser instance.
  #
  # @param html_content [String] HTML string to render
  # @param pdf_options [Hash] Options passed to Ferrum browser.pdf (e.g. format: :A4, landscape: false, print_background: true)
  # @param browser_overrides [Hash] Optional browser config overrides
  # @param max_retries [Integer] Retry attempts on startup / timeout errors (default: 2)
  # @return [String] Binary PDF data
  def self.render(html_content, pdf_options = {}, browser_overrides: {}, max_retries: 2, **extra_pdf_options)
    resolved_pdf_options = if pdf_options.is_a?(Hash)
      pdf_options.merge(extra_pdf_options)
    else
      extra_pdf_options
    end

    attempts = 0

    begin
      attempts += 1
      render_isolated(html_content, resolved_pdf_options, browser_overrides)
    rescue StandardError => e
      if attempts <= max_retries
        Rails.logger.warn("[FerrumPdfGenerator] Attempt #{attempts} failed with #{e.class}: #{e.message}. Retrying in 1.5s...")
        sleep 1.5
        retry
      else
        Rails.logger.error("[FerrumPdfGenerator] All #{attempts} attempts failed: #{e.message}\n#{e.backtrace&.first(15)&.join("\n")}")
        raise
      end
    end
  end

  # Builds standardized browser options suitable for headless Linux servers and background workers
  def self.build_browser_options(overrides = {})
    timeout = ENV.fetch("FERRUM_TIMEOUT", DEFAULT_TIMEOUT).to_i
    process_timeout = ENV.fetch("FERRUM_PROCESS_TIMEOUT", DEFAULT_PROCESS_TIMEOUT).to_i

    opts = {
      timeout: timeout,
      process_timeout: process_timeout,
      window_size: DEFAULT_WINDOW_SIZE,
      headless: "new",
      env: { "DBUS_SESSION_BUS_ADDRESS" => "/dev/null" },
      browser_options: DEFAULT_BROWSER_OPTIONS.dup
    }

    if overrides.present?
      if overrides[:browser_options].is_a?(Hash)
        opts[:browser_options].merge!(overrides.delete(:browser_options))
      end
      opts.merge!(overrides)
    end

    opts
  end

  private_class_method def self.render_isolated(html_content, pdf_options, browser_overrides)
    tempfile = nil
    browser = nil

    begin
      tempfile = Tempfile.create([ "report_", ".html" ], binmode: true)
      tempfile.write(html_content.to_s.b)
      tempfile.flush

      browser = Ferrum::Browser.new(build_browser_options(browser_overrides))
      browser.go_to("file://#{tempfile.path}")

      pdf_opts = {
        format: :A4,
        landscape: false,
        print_background: true
      }.merge(pdf_options)

      pdf_data = browser.pdf(**pdf_opts)

      # Normalize Base64-encoded PDF return values if necessary
      if pdf_data.present? && !pdf_data.start_with?("%PDF")
        pdf_data = Base64.decode64(pdf_data)
      end

      pdf_data
    ensure
      if browser
        begin
          browser.quit
        rescue StandardError => quit_err
          Rails.logger.warn("[FerrumPdfGenerator] Browser quit warning: #{quit_err.message}")
        end
      end

      if tempfile
        begin
          tempfile.close unless tempfile.closed?
          File.unlink(tempfile.path) if File.exist?(tempfile.path)
        rescue StandardError => temp_err
          Rails.logger.warn("[FerrumPdfGenerator] Tempfile cleanup warning: #{temp_err.message}")
        end
      end
    end
  end
end
