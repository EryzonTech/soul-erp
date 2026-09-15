class ReportExportJob < ApplicationJob
  queue_as :default

  def perform(export_token, report_type, params_hash, institute_id)
    institute = Institute.find(institute_id)

    # Stage 1: Enqueued & Fetching Filters (15%)
    update_progress(export_token, "processing", 15, "Fetching report filters & records...")

    controller = InstituteAdmin::ReportsController.new
    controller.params = ActionController::Parameters.new(params_hash)
    controller.instance_variable_set(:@current_institute, institute)
    controller.define_singleton_method(:current_institute) { institute }

    case report_type
    when "assignment_pdf"
      controller.send(:fetch_assignment_reports)
      report_rows = controller.instance_variable_get(:@report_rows) || []
      update_progress(export_token, "processing", 40, "Aggregated #{report_rows.size} assignment records...")
      update_progress(export_token, "processing", 70, "Rendering PDF layout...")
      file_data = controller.send(:generate_assignment_pdf_with_ferrum)
      content_type = "application/pdf"
      filename = "assignment_report_#{Date.current.strftime('%Y%m%d')}.pdf"
    when "assignment_csv"
      controller.send(:fetch_assignment_reports)
      report_rows = controller.instance_variable_get(:@report_rows) || []
      update_progress(export_token, "processing", 40, "Aggregated #{report_rows.size} assignment records...")
      update_progress(export_token, "processing", 75, "Formatting CSV spreadsheet output...")
      file_data = controller.send(:generate_assignment_csv)
      content_type = "text/csv"
      filename = "assignment_report_#{Date.current.strftime('%Y%m%d')}.csv"
    when "individual_assignment_pdf"
      controller.send(:fetch_individual_assignment_reports)
      report_rows = controller.instance_variable_get(:@report_rows) || []
      update_progress(export_token, "processing", 40, "Aggregated #{report_rows.size} report records...")
      update_progress(export_token, "processing", 70, "Rendering PDF layout...")
      file_data = controller.send(:generate_individual_assignment_pdf_with_ferrum)
      content_type = "application/pdf"
      filename = "individual_assignment_report_#{Date.current.strftime('%Y%m%d')}.pdf"
    when "consolidated_response_excel"
      controller.send(:fetch_consolidated_response_reports)
      report_rows = controller.instance_variable_get(:@report_rows) || []
      update_progress(export_token, "processing", 40, "Aggregated #{report_rows.size} consolidated records...")
      update_progress(export_token, "processing", 75, "Generating Excel SpreadsheetML workbook...")
      file_data = controller.send(:generate_consolidated_response_excel)
      content_type = "application/vnd.ms-excel; charset=utf-8"
      filename = "consolidated_response_report_#{Date.current.strftime('%Y%m%d')}.xls"
    when "consolidated_response_csv"
      controller.send(:fetch_consolidated_response_reports)
      report_rows = controller.instance_variable_get(:@report_rows) || []
      update_progress(export_token, "processing", 40, "Aggregated #{report_rows.size} consolidated records...")
      update_progress(export_token, "processing", 75, "Formatting CSV spreadsheet output...")
      file_data = controller.send(:generate_consolidated_response_csv)
      content_type = "text/csv"
      filename = "consolidated_response_report_#{Date.current.strftime('%Y%m%d')}.csv"
    when "consolidated_matrix_excel"
      controller.send(:fetch_consolidated_matrix_reports)
      matrix_rows = controller.instance_variable_get(:@matrix_rows) || []
      update_progress(export_token, "processing", 40, "Aggregated #{matrix_rows.size} matrix submission rows...")
      update_progress(export_token, "processing", 75, "Generating Excel SpreadsheetML matrix workbook...")
      file_data = controller.send(:generate_consolidated_matrix_excel)
      content_type = "application/vnd.ms-excel; charset=utf-8"
      filename = "consolidated_question_matrix_#{Date.current.strftime('%Y%m%d')}.xls"
    when "consolidated_matrix_csv"
      controller.send(:fetch_consolidated_matrix_reports)
      matrix_rows = controller.instance_variable_get(:@matrix_rows) || []
      update_progress(export_token, "processing", 40, "Aggregated #{matrix_rows.size} matrix submission rows...")
      update_progress(export_token, "processing", 75, "Formatting CSV spreadsheet output...")
      file_data = controller.send(:generate_consolidated_matrix_csv)
      content_type = "text/csv"
      filename = "consolidated_question_matrix_#{Date.current.strftime('%Y%m%d')}.csv"
    else # "individual_assignment_csv"
      controller.send(:fetch_individual_assignment_reports)
      report_rows = controller.instance_variable_get(:@report_rows) || []
      update_progress(export_token, "processing", 40, "Aggregated #{report_rows.size} report records...")
      update_progress(export_token, "processing", 75, "Formatting CSV spreadsheet output...")
      file_data = controller.send(:generate_individual_assignment_csv)
      content_type = "text/csv"
      filename = "individual_assignment_report_#{Date.current.strftime('%Y%m%d')}.csv"
    end

    # Stage 4: Finalizing & Packaging (92%)
    update_progress(export_token, "processing", 92, "Finalizing download package...")

    export_dir = Rails.root.join("tmp", "exports")
    FileUtils.mkdir_p(export_dir)

    # Periodic cleanup of exports older than 2 hours
    begin
      Dir.glob(export_dir.join("*")).each do |old_file|
        File.delete(old_file) if File.file?(old_file) && File.mtime(old_file) < 2.hours.ago
      end
    rescue StandardError => cleanup_err
      Rails.logger.warn("Export cleanup error: #{cleanup_err.message}")
    end

    filepath = export_dir.join("#{export_token}_#{filename}")
    File.binwrite(filepath, file_data)

    file_info = {
      filepath: filepath.to_s,
      data: (file_data.bytesize < 5.megabytes ? file_data : nil),
      content_type: content_type,
      filename: filename
    }
    Rails.cache.write("export_file_#{export_token}", file_info, expires_in: 2.hours)

    # Stage 5: Completed (100%)
    update_progress(export_token, "completed", 100, "Export ready for download!")
  rescue StandardError => e
    Rails.logger.error("ReportExportJob failed: #{e.message}\n#{e.backtrace.join("\n")}")
    update_progress(export_token, "failed", 0, "Export failed: #{e.message}")
  end

  private

  def update_progress(token, status, progress, message)
    Rails.cache.write("export_progress_#{token}", { status: status, progress: progress, message: message }, expires_in: 2.hours)
  end
end
