# frozen_string_literal: true

require "test_helper"

class FerrumPdfGeneratorTest < ActiveSupport::TestCase
  test "renders valid PDF binary data from HTML" do
    html = "<html><body><h1>Report Header</h1><p>Sample report content</p></body></html>"
    pdf_data = FerrumPdfGenerator.render(html, format: :A4)

    assert pdf_data.present?
    assert pdf_data.start_with?("%PDF-"), "Generated PDF data should start with %PDF- header"
    assert pdf_data.bytesize > 1000, "PDF data should contain non-trivial byte size"
  end

  test "accepts custom browser overrides and landscape layout" do
    html = "<html><body><table border='1'><tr><td>Cell 1</td><td>Cell 2</td></tr></table></body></html>"
    pdf_data = FerrumPdfGenerator.render(
      html,
      { format: :A4, landscape: true, print_background: true },
      browser_overrides: { timeout: 30 }
    )

    assert pdf_data.present?
    assert pdf_data.start_with?("%PDF-")
  end

  test "retries on transient failure before succeeding" do
    html = "<html><body><p>Retry Test</p></body></html>"
    call_count = 0

    # Temporarily intercept render_isolated to fail once, then call original
    original_method = FerrumPdfGenerator.method(:render_isolated)
    FerrumPdfGenerator.define_singleton_method(:render_isolated) do |*args|
      call_count += 1
      if call_count == 1
        raise Ferrum::ProcessTimeoutError.new(10, "Simulated initial startup timeout")
      else
        original_method.call(*args)
      end
    end

    begin
      pdf_data = FerrumPdfGenerator.render(html, max_retries: 2)
      assert_equal 2, call_count, "Expected render to retry after initial failure"
      assert pdf_data.start_with?("%PDF-")
    ensure
      # Restore original method
      FerrumPdfGenerator.define_singleton_method(:render_isolated, original_method)
    end
  end

  test "build_browser_options includes necessary headless linux flags" do
    options = FerrumPdfGenerator.build_browser_options
    assert_equal 60, options[:timeout]
    assert_equal 60, options[:process_timeout]
    assert_equal "new", options[:headless]
    assert_equal "/dev/null", options[:env]["DBUS_SESSION_BUS_ADDRESS"]

    browser_opts = options[:browser_options]
    assert browser_opts.key?("no-sandbox")
    assert browser_opts.key?("disable-gpu")
    assert browser_opts.key?("disable-dev-shm-usage")
    assert browser_opts.key?("no-zygote")
    assert browser_opts.key?("disable-software-rasterizer")
  end
end
