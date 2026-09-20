module InstituteAdmin
  class ReportsController < InstituteAdmin::BaseController
    def index
      # Just show the main reports navigation page
    end

    def assignment_reports_menu
      # Show menu for assignment reports types
    end

    def assignment_reports
      set_report_filters

      respond_to do |format|
        format.html do
          fetch_assignment_reports_paginated
        end
        format.csv do
          fetch_assignment_reports
          send_data generate_assignment_csv, filename: "assignment_report_#{Date.current}.csv"
        end
        format.pdf do
          fetch_assignment_reports
          pdf_data = generate_assignment_pdf_with_ferrum
          disposition = params[:download].present? ? "attachment" : "inline"
          send_data pdf_data, filename: "assignment_report_#{Date.current}.pdf", type: "application/pdf", disposition: disposition
        end
      end
    end

    def consolidated_response_report
      # Matrix view is default for Consolidated Report unless detailed view or download/scroll is explicitly requested
      if request.format.html? && params[:view] != "detailed" && !request.xhr? && params[:scroll].blank?
        redirect_to consolidated_matrix_report_institute_admin_reports_path(request.query_parameters)
        return
      end

      set_consolidated_report_filters

      respond_to do |format|
        format.html do
          fetch_consolidated_response_reports_paginated
          if (params[:scroll].present? || request.xhr?) && params[:page].to_i > 1
            render partial: "consolidated_response_rows",
                   locals: { rows: @paginated_rows, start_index: @pagy ? @pagy.from : 1 }
          end
        end
        format.json do
          fetch_consolidated_response_reports_paginated
          page_num = [ (params[:page] || 1).to_i, 1 ].max
          render json: {
            html: render_to_string(partial: "consolidated_response_rows", formats: [ :html ], locals: { rows: @paginated_rows, start_index: @pagy ? @pagy.from : 1 }),
            page: page_num,
            has_more: @pagy ? (page_num < @pagy.pages) : false,
            loaded_count: [ (@pagy ? @pagy.offset : 0) + @paginated_rows.size, @total_report_count ].min,
            total_count: @total_report_count
          }
        end
        format.xls do
          fetch_consolidated_response_reports
          send_data generate_consolidated_response_excel,
                    filename: "consolidated_response_report_#{Date.current.strftime('%Y%m%d')}.xls",
                    type: "application/vnd.ms-excel; charset=utf-8",
                    disposition: "attachment"
        end
        format.csv do
          fetch_consolidated_response_reports
          send_data generate_consolidated_response_csv,
                    filename: "consolidated_response_report_#{Date.current.strftime('%Y%m%d')}.csv",
                    type: "text/csv; charset=utf-8",
                    disposition: "attachment"
        end
      end
    end

    def consolidated_matrix_report
      set_consolidated_matrix_filters

      respond_to do |format|
        format.html do
          fetch_consolidated_matrix_reports_paginated
          if (params[:scroll].present? || request.xhr?) && params[:page].to_i > 1
            render partial: "consolidated_matrix_rows",
                   locals: { rows: @paginated_matrix_rows, start_index: @pagy ? @pagy.from : 1, matrix_questions: @matrix_questions }
          end
        end
        format.json do
          fetch_consolidated_matrix_reports_paginated
          page_num = [ (params[:page] || 1).to_i, 1 ].max
          render json: {
            html: render_to_string(partial: "consolidated_matrix_rows", formats: [ :html ], locals: { rows: @paginated_matrix_rows, start_index: @pagy ? @pagy.from : 1, matrix_questions: @matrix_questions }),
            page: page_num,
            has_more: @pagy ? (page_num < @pagy.pages) : false,
            loaded_count: [ (@pagy ? @pagy.offset : 0) + @paginated_matrix_rows.size, @total_matrix_count ].min,
            total_count: @total_matrix_count
          }
        end
        format.xls do
          fetch_consolidated_matrix_reports
          send_data generate_consolidated_matrix_excel,
                    filename: "consolidated_question_matrix_#{Date.current.strftime('%Y%m%d')}.xls",
                    type: "application/vnd.ms-excel; charset=utf-8",
                    disposition: "attachment"
        end
        format.csv do
          fetch_consolidated_matrix_reports
          send_data generate_consolidated_matrix_csv,
                    filename: "consolidated_question_matrix_#{Date.current.strftime('%Y%m%d')}.csv",
                    type: "text/csv; charset=utf-8",
                    disposition: "attachment"
        end
      end
    end

    def feedback_reports
      # Just show the feedback reports menu page
    end

    def section_feedback_reports
      @date_range = params[:date_range]
      @start_date = safe_parse_date(params[:start_date], Date.current)
      @end_date = safe_parse_date(params[:end_date], Date.current)
      @section_id = params[:section_id]
      @training_program_id = params[:training_program_id]

      # Always fetch reports for CSV/PDF format, or when filter is applied in HTML format
      if params[:format].in?([ "csv", "pdf" ]) || (params[:commit].present? && params[:submission_status].present?)
        fetch_section_feedback_reports
      end

      respond_to do |format|
        format.html
        format.csv {
          if @submitted_feedbacks.nil? && @not_submitted_participants.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_feedbacks = []
            @not_submitted_participants = []
          end
          send_data generate_section_feedback_csv, filename: "section_feedback_report_#{Date.current}.csv"
        }
        format.pdf {
          if @submitted_feedbacks.nil? && @not_submitted_participants.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_feedbacks = []
            @not_submitted_participants = []
          end

          # Render PDF using Prawn or WickedPDF
          render_section_feedback_report_pdf
        }
      end
    end

    def individual_feedback_reports
      @date_range = params[:date_range]
      @start_date = safe_parse_date(params[:start_date], Date.current)
      @end_date = safe_parse_date(params[:end_date], Date.current)
      @section_id = params[:section_id]
      @participant_id = params[:participant_id]
      @training_program_id = params[:training_program_id]

      # Load participants for the selected section
      @participants = if @section_id.present?
                       current_institute.participants.includes(:user).where(section_id: @section_id)
      else
                       []
      end

      # Always fetch reports for CSV/PDF format, or when filter is applied in HTML format
      if params[:format].in?([ "csv", "pdf" ]) || (params[:commit].present? && params[:submission_status].present?)
        fetch_individual_feedback_reports
      end

      respond_to do |format|
        format.html
        format.csv {
          if @submitted_feedbacks.nil? && @not_submitted_training_programs.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_feedbacks = []
            @not_submitted_training_programs = []
          end
          send_data generate_individual_feedback_csv, filename: "individual_feedback_report_#{Date.current}.csv"
        }
        format.pdf {
          if @submitted_feedbacks.nil? && @not_submitted_training_programs.nil?
            # Initialize empty collections to prevent nil errors
            @submitted_feedbacks = []
            @not_submitted_training_programs = []
          end

          # Render PDF using Prawn or WickedPDF
          render_individual_feedback_report_pdf
        }
      end
    end

    def certificates
      # Handle certificate options page
    end

    def generate_certificate
      @sections = current_institute.sections.active
      @certificate_configurations = current_institute.certificate_configurations.active

      # Load data based on parameters
      @section_id = params[:section_id]
      @participant_id = params[:participant_id]
      @assignment_id = params[:assignment_id]

      # Load participants if section is selected
      @participants = if @section_id.present?
                       current_institute.participants.includes(:user).where(section_id: @section_id)
      else
                       []
      end

      # Load assignments if participant is selected
      @assignments = if @participant_id.present?
                      participant = current_institute.participants.find_by(id: @participant_id)

                      if participant
                        # Get all assignments for this participant (both individual and section assignments)
                        individual_assignments = Assignment.joins(:assignment_participants)
                                                        .where(assignment_participants: { participant_id: @participant_id })

                        section_assignments = Assignment.joins(:assignment_sections)
                                                     .where(assignment_sections: { section_id: participant.section_id })

                        Assignment.where(id: individual_assignments.pluck(:id) + section_assignments.pluck(:id))
                                .distinct.order(created_at: :desc)
                      else
                        []
                      end
      else
                      []
      end
    end

    def create_certificate
      @section_id = params[:section_id]
      @participant_id = params[:participant_id]
      @assignment_id = params[:assignment_id]
      @certificate_configuration_id = params[:certificate_configuration_id]

      # Validate all required parameters
      unless @section_id.present? && @participant_id.present? && @assignment_id.present? && @certificate_configuration_id.present?
        redirect_to generate_certificate_institute_admin_reports_path, alert: "All fields are required"
        return
      end

      # Find records
      @participant = current_institute.participants.find_by(id: @participant_id)
      @assignment = current_institute.assignments.find_by(id: @assignment_id)
      @certificate_configuration = current_institute.certificate_configurations.find_by(id: @certificate_configuration_id)

      # Validate records exist
      errors = []
      errors << "Participant not found" unless @participant
      errors << "Assignment not found" unless @assignment
      errors << "Certificate configuration not found" unless @certificate_configuration

      if errors.any?
        redirect_to generate_certificate_institute_admin_reports_path, alert: "Invalid selection: #{errors.join(', ')}"
        return
      end

      # Check if this certificate already exists
      if IndividualCertificate.exists?(
          participant_id: @participant_id,
          assignment_id: @assignment_id,
          certificate_configuration_id: @certificate_configuration_id
        )
        redirect_to view_certificates_institute_admin_reports_path, alert: "A certificate already exists for this participant and assignment"
        return
      end

      # Create certificate record
      @certificate = IndividualCertificate.new(
        participant: @participant,
        assignment: @assignment,
        certificate_configuration: @certificate_configuration,
        institute: current_institute
      )

      if @certificate.save
        redirect_to view_certificates_institute_admin_reports_path,
                    notice: "Certificate successfully generated. <a href='#{show_certificate_on_demand_institute_admin_report_path(@certificate)}' target='_blank'>View Certificate</a>".html_safe
      else
        redirect_to generate_certificate_institute_admin_reports_path(
          section_id: @section_id,
          participant_id: @participant_id,
          assignment_id: @assignment_id,
          certificate_configuration_id: @certificate_configuration_id
        ), alert: "Failed to generate certificate: #{@certificate.errors.full_messages.join(', ')}"
      end
    end

    def generate_section_certificate
      @sections = current_institute.sections.active
      @certificate_configurations = current_institute.certificate_configurations.active
      @assignments = current_institute.assignments.order(created_at: :desc)

      # optionally preselect section from params
      @section_id = params[:section_id]
    end

    def create_section_certificate
      section_id = params[:section_id]
      assignment_id = params[:assignment_id]
      certificate_configuration_id = params[:certificate_configuration_id]

      unless section_id.present? && assignment_id.present? && certificate_configuration_id.present?
        redirect_to generate_section_certificate_institute_admin_reports_path, alert: "All fields are required"
        return
      end

      section = current_institute.sections.find_by(id: section_id)
      assignment = current_institute.assignments.find_by(id: assignment_id)
      certificate_configuration = current_institute.certificate_configurations.find_by(id: certificate_configuration_id)

      errors = []
      errors << "Section not found" unless section
      errors << "Assignment not found" unless assignment
      errors << "Certificate configuration not found" unless certificate_configuration

      if errors.any?
        redirect_to generate_section_certificate_institute_admin_reports_path, alert: "Invalid selection: #{errors.join(', ')}"
        return
      end

      participants = current_institute.participants.where(section_id: section.id)

      created = 0
      skipped = 0
      failed = 0
      failures = []

      IndividualCertificate.transaction do
        participants.find_each do |participant|
          existing = IndividualCertificate.find_by(participant_id: participant.id, assignment_id: assignment.id, certificate_configuration_id: certificate_configuration.id)
          if existing
            skipped += 1
            next
          end

          cert = IndividualCertificate.new(
            participant: participant,
            assignment: assignment,
            certificate_configuration: certificate_configuration,
            institute: current_institute
          )

          if cert.save
            # attempt to generate PDF now; capture failures but do not rollback entire transaction for generation errors
            begin
              success = generate_individual_certificate(cert)
              if success
                created += 1
              else
                failed += 1
                failures << "#{participant.full_name}: generation failed"
              end
            rescue => e
              failed += 1
              failures << "#{participant.full_name}: #{e.message}"
            end
          else
            failed += 1
            failures << "#{participant.full_name}: #{cert.errors.full_messages.join(', ')}"
          end
        end
      end

      notice_parts = []
      notice_parts << "Created: #{created}" if created > 0
      notice_parts << "Skipped (already exists): #{skipped}" if skipped > 0
      notice_parts << "Failed: #{failed}" if failed > 0

      if failures.any?
        redirect_to view_certificates_institute_admin_reports_path, alert: "Section generation completed - #{notice_parts.join(', ')}. Errors: #{failures.join('; ')}"
      else
        redirect_to view_certificates_institute_admin_reports_path, notice: "Section generation completed - #{notice_parts.join(', ')}"
      end
    end

    def view_certificates
      # Read optional filters
      @section_id = params[:section_id]
      @certificate_configuration_id = params[:certificate_configuration_id]

      # Load available configurations for the filter dropdown
      @certificate_configurations = current_institute.certificate_configurations.active

      # Build base query
      base = IndividualCertificate.includes(participant: [ :user, :section ], assignment: [], certificate_configuration: [])
                   .where(institute_id: current_institute.id)

      # Apply section filter (via participant's section)
      if @section_id.present?
        base = base.joins(participant: :section).where(participants: { section_id: @section_id })
      end

      # Apply certificate configuration filter
      if @certificate_configuration_id.present?
        base = base.where(certificate_configuration_id: @certificate_configuration_id)
      end

      # Pagination and ordering
      @certificates = base.order(generated_at: :desc).page(params[:page]).per(10)

      # Get section-wise certificate counts for the bar graph
      @section_certificate_counts = IndividualCertificate.joins(participant: :section)
                                            .where(institute_id: current_institute.id)
                                            .group("sections.name")
                                            .order("sections.name")
                                            .count
    end

    def show_certificate
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Generate PDF content on-demand
      pdf_content = generate_individual_certificate(@certificate)

      if pdf_content
        send_data pdf_content,
                  filename: "certificate_#{@certificate.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      else
        redirect_to view_certificates_institute_admin_reports_path,
                    alert: "Failed to generate certificate: #{@certificate.errors.full_messages.join(', ')}"
      end
    end

    def delete_certificate
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Delete the physical file if it exists
      File.delete(@certificate.file_path) if @certificate.filename.present? && File.exist?(@certificate.file_path)

      # Delete the record
      @certificate.destroy

      redirect_to view_certificates_institute_admin_reports_path, notice: "Certificate successfully deleted"
    end

    def regenerate_certificate
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Delete the existing file if it exists
      if @certificate.filename.present? && File.exist?(@certificate.file_path)
        File.delete(@certificate.file_path)
      end

      # Regenerate the certificate PDF
      success = generate_individual_certificate(@certificate)

      if success && @certificate.save
        redirect_to view_certificates_institute_admin_reports_path, notice: "Certificate successfully regenerated. <a href='#{show_certificate_institute_admin_reports_path(@certificate)}' target='_blank'>View Certificate</a>".html_safe
      else
        error_messages = @certificate.errors.full_messages
        error_messages << "Failed to regenerate certificate PDF" unless success
        redirect_to view_certificates_institute_admin_reports_path, alert: "Failed to regenerate certificate: #{error_messages.join(', ')}"
      end
    end

    def show_certificate_on_demand
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Generate PDF content on-demand
      pdf_content = generate_individual_certificate(@certificate)

      if pdf_content
        send_data pdf_content,
                  filename: "certificate_#{@certificate.id}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      else
        redirect_to view_certificates_institute_admin_reports_path,
                    alert: "Failed to generate certificate: #{@certificate.errors.full_messages.join(', ')}"
      end
    end

    def download_certificate_on_demand
      @certificate = current_institute.individual_certificates.find(params[:id])

      # Generate PDF content on-demand
      pdf_content = generate_individual_certificate(@certificate)

      if pdf_content
        send_data pdf_content,
                  filename: "certificate_#{@certificate.id}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      else
        redirect_to view_certificates_institute_admin_reports_path,
                    alert: "Failed to generate certificate: #{@certificate.errors.full_messages.join(', ')}"
      end
    end

    def individual_assignment_reports
      set_report_filters

      # Load participants for the selected sections (or all if none selected)
      @participants = if @selected_section_ids.present? && !@selected_section_ids.include?("all")
                        current_institute.participants.includes(:user, :section).where(section_id: @selected_section_ids)
                      else
                        current_institute.participants.includes(:user, :section)
                      end

      respond_to do |format|
        format.html do
          fetch_individual_assignment_reports_paginated
        end
        format.csv {
          fetch_individual_assignment_reports
          if @submitted_logs.nil? && @not_submitted_assignments.nil?
            @submitted_logs = []
            @not_submitted_assignments = []
          end
          send_data generate_individual_assignment_csv, filename: "individual_assignment_report_#{Date.current}.csv"
        }
        format.pdf {
          fetch_individual_assignment_reports
          if @submitted_logs.nil? && @not_submitted_assignments.nil?
            @submitted_logs = []
            @not_submitted_assignments = []
          end
          render_individual_assignment_report_pdf
        }
      end
    end

    def assignment_response_details
      @selected_date = params[:date].present? ? Date.parse(params[:date]) : Date.current
      @participant = current_institute.participants.includes(:user, :section).find(params[:participant_id])
      @assignment = current_institute.assignments.find(params[:assignment_id])

      @responses = @participant.assignment_responses
                               .where(assignment: @assignment, response_date: @selected_date)
                               .includes(:question)
                               .index_by(&:question_id)

      @grouped_questions = @assignment.questions_grouped_by_bundle_for_date(@selected_date)
      @total_questions_count = @grouped_questions.values.flatten.size
      @answered_count = @responses.size
    end

    def export_async
      export_token = SecureRandom.hex(12)
      report_type = params[:export_type] || "individual_assignment_pdf"

      Rails.cache.write("export_progress_#{export_token}", { status: "queued", progress: 5, message: "Enqueuing background export..." }, expires_in: 30.minutes)

      ReportExportJob.perform_later(export_token, report_type, params.permit!.to_h, current_institute.id)

      render json: { export_token: export_token, status: "queued" }
    end

    def export_status
      export_token = params[:export_token]
      if export_token.blank?
        render json: { status: "failed", progress: 0, message: "Invalid export token." }, status: :bad_request
        return
      end

      progress_info = Rails.cache.read("export_progress_#{export_token}")

      # If progress info is missing from cache, check if file exists on disk
      if progress_info.nil?
        export_dir = Rails.root.join("tmp", "exports")
        if Dir.glob(export_dir.join("#{export_token}_*")).any?
          progress_info = { status: "completed", progress: 100, message: "Export ready for download!" }
        else
          progress_info = { status: "queued", progress: 5, message: "Preparing job..." }
        end
      end

      if progress_info[:status] == "completed"
        progress_info[:download_url] = download_export_institute_admin_reports_path(export_token: export_token)
      end

      render json: progress_info
    end

    def download_export
      export_token = params[:export_token]
      if export_token.blank?
        respond_to do |format|
          format.html { redirect_back fallback_location: institute_admin_reports_path, alert: "Invalid export token." }
          format.all { render plain: "Invalid export token.", status: :bad_request }
        end
        return
      end

      file_info = Rails.cache.read("export_file_#{export_token}")

      if file_info.present?
        if file_info[:filepath].present? && File.exist?(file_info[:filepath])
          send_file file_info[:filepath],
                    filename: file_info[:filename],
                    type: file_info[:content_type],
                    disposition: "attachment"
        elsif file_info[:data].present?
          send_data file_info[:data],
                    filename: file_info[:filename],
                    type: file_info[:content_type],
                    disposition: "attachment"
        else
          respond_to do |format|
            format.html { redirect_back fallback_location: institute_admin_reports_path, alert: "Export file expired or not found. Please regenerate." }
            format.all { render plain: "Export file expired or not found.", status: :not_found }
          end
        end
      else
        # Fallback check on filesystem directly in case cache was flushed or memory store differed
        export_dir = Rails.root.join("tmp", "exports")
        matching_files = Dir.glob(export_dir.join("#{export_token}_*"))
        if matching_files.any? && File.exist?(matching_files.first)
          matched_path = matching_files.first
          filename = File.basename(matched_path).sub(/^#{Regexp.escape(export_token)}_/, "")
          content_type = filename.ends_with?(".pdf") ? "application/pdf" : (filename.ends_with?(".csv") ? "text/csv" : "application/vnd.ms-excel")
          send_file matched_path,
                    filename: filename,
                    type: content_type,
                    disposition: "attachment"
        else
          respond_to do |format|
            format.html { redirect_back fallback_location: institute_admin_reports_path, alert: "Export file expired or not found. Please regenerate." }
            format.all { render plain: "Export file expired or not found.", status: :not_found }
          end
        end
      end
    end

    def certificate_stats
      # Get certificates for current institute only
      base_query = IndividualCertificate.joins(:certificate_configuration)
                             .where(certificate_configurations: { institute_id: current_institute.id })

      # Get total count of certificates
      @total_certificates = base_query.count

      # Get certificates created in the last 7 days
      @recent_certificates = base_query.where("individual_certificates.created_at >= ?", 7.days.ago).count

      # Get certificate types (distinct configurations)
      @certificate_types = current_institute.certificate_configurations.count

      # Get certificate count by configuration
      @certificates_by_config = base_query.group("certificate_configurations.name")
                                        .order("count_all DESC")
                                        .count

      # Get certificates by month for the current year
      @certificates_by_month = base_query.where("individual_certificates.created_at >= ?", Time.zone.now.beginning_of_year)
                                       .group(Arel.sql("DATE_TRUNC('month', individual_certificates.created_at)"))
                                       .order(Arel.sql("DATE_TRUNC('month', individual_certificates.created_at)"))
                                       .count
                                       .transform_keys { |k| k.strftime("%B") }

      # Get top 10 participants with most certificates
      @top_participants = base_query.joins(participant: :user)
                                   .group(Arel.sql("users.first_name || ' ' || users.last_name"))
                                   .order("count_all DESC")
                                   .limit(10)
                                   .count

      # Get certificates by section
      @certificates_by_section = base_query.joins(participant: :section)
                                         .group("sections.name")
                                         .order("count_all DESC")
                                         .count

      # Monthly growth rate
      current_month_count = base_query.where("individual_certificates.created_at >= ?", Time.zone.now.beginning_of_month).count
      previous_month_count = base_query.where("individual_certificates.created_at >= ? AND individual_certificates.created_at <= ?",
                                             1.month.ago.beginning_of_month,
                                             1.month.ago.end_of_month).count
      @monthly_growth = previous_month_count.zero? ? 100 : ((current_month_count - previous_month_count).to_f / previous_month_count * 100).round(2)

      render :certificate_stats
    end

    def certificate_configurations
      @certificate_configs = CertificateConfiguration.order(created_at: :desc)
                                                  .page(params[:page]).per(10)
    end

    def toggle_publish_certificate
      @certificate = current_institute.individual_certificates.find(params[:id])
      @certificate.update(published: !@certificate.published)

      redirect_to view_certificates_institute_admin_reports_path,
                  notice: "Certificate #{@certificate.published? ? 'published' : 'unpublished'} successfully"
    end

    def publish_multiple_certificates
      certificate_ids = params[:certificate_ids]
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      begin
        IndividualCertificate.transaction do
          certificates.update_all(published: true)
        end

        render json: { success: true, message: "Successfully published #{certificates.count} certificates" }
      rescue => e
        render json: { success: false, message: e.message }, status: :unprocessable_entity
      end
    end

    def delete_multiple_certificates
      certificate_ids = params[:certificate_ids]
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      begin
        IndividualCertificate.transaction do
          certificates.find_each do |cert|
            # attempt to delete the file if present
            File.delete(cert.file_path) if cert.filename.present? && File.exist?(cert.file_path)
            cert.destroy
          end
        end

        render json: { success: true, message: "Successfully deleted #{certificates.count} certificates" }
      rescue => e
        render json: { success: false, message: e.message }, status: :unprocessable_entity
      end
    end

    def unpublish_multiple_certificates
      certificate_ids = params[:certificate_ids]
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      begin
        IndividualCertificate.transaction do
          certificates.update_all(published: false)
        end

        render json: { success: true, message: "Successfully unpublished #{certificates.count} certificates" }
      rescue => e
        render json: { success: false, message: e.message }, status: :unprocessable_entity
      end
    end

    def download_multiple_certificates
      certificate_ids = params[:certificate_ids] || []
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      if certificates.empty?
        render json: { success: false, message: "No certificates found" }, status: :not_found
        return
      end

      require "zip"
      temp_file = Tempfile.new([ "certificates-", ".zip" ])
      begin
        Zip::OutputStream.open(temp_file.path) do |zos|
          certificates.find_each do |cert|
            # generate or fetch PDF content
            pdf_content = generate_individual_certificate(cert)
            next unless pdf_content
            filename = "certificate-#{cert.id}.pdf"
            zos.put_next_entry(filename)
            zos.write(pdf_content)
          end
        end

        send_data File.read(temp_file.path), filename: "certificates_#{Time.current.strftime('%Y%m%d%H%M%S')}.zip", type: "application/zip"
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    def regenerate_multiple_certificates
      certificate_ids = params[:certificate_ids] || []
      certificates = current_institute.individual_certificates.where(id: certificate_ids)

      updated = 0
      certificates.find_each do |cert|
        # remove old file if exists
        File.delete(cert.file_path) if cert.filename.present? && File.exist?(cert.file_path)
        success = generate_individual_certificate(cert)
        updated += 1 if success
      end

      render json: { success: true, message: "Regenerated #{updated} certificates" }
    end

    private

    def fetch_assignment_reports
      set_report_filters
      base_query = build_assignment_report_base_query
      all_participants = build_all_participants_query

      submitted_participant_ids = base_query.distinct.pluck(:participant_id).compact
      @submitted_count = submitted_participant_ids.size
      @not_submitted_participants = all_participants.where.not(id: submitted_participant_ids)
      @pending_count = @not_submitted_participants.count
      @total_assigned_count = @submitted_count + @pending_count
      @participation_rate = (@total_assigned_count > 0) ? ((@submitted_count.to_f / @total_assigned_count) * 100).round(1) : 0.0

      # Participant Type Distributions for all 4 KPIs
      @submitted_by_type = if submitted_participant_ids.any?
                             current_institute.participants.where(id: submitted_participant_ids).group(:participant_type).count
                           else
                             {}
                           end
      @pending_by_type = @not_submitted_participants.group("participants.participant_type").count

      @total_assigned_by_type = {}
      @completion_rate_by_type = {}
      Participant.participant_types.keys.each do |ptype|
        sub = @submitted_by_type[ptype] || 0
        pnd = @pending_by_type[ptype] || 0
        tot = sub + pnd
        @total_assigned_by_type[ptype] = tot
        @completion_rate_by_type[ptype] = tot > 0 ? ((sub.to_f / tot) * 100).round(1) : 0.0
      end

      resolve_report_titles

      only_submitted = (@selected_statuses == ["submitted"]) || (params[:submission_status] == "submitted" && @selected_statuses.blank?)
      only_pending = (@selected_statuses == ["not_submitted"]) || (params[:submission_status] == "not_submitted" && @selected_statuses.blank?)

      # Unified report rows
      @report_rows = []

      unless only_pending
        @submitted_logs = base_query.order(response_date: :desc)
        @submitted_logs.each do |log|
          @report_rows << {
            date: log.response_date,
            participant_id: log.participant_id,
            assignment_id: log.assignment_id,
            participant_name: log.participant&.full_name.to_s.presence || "Unknown",
            participant_email: log.participant&.email.to_s.presence || "N/A",
            section_name: log.participant&.section&.name || "N/A",
            assignment_title: log.assignment&.title || "Assignment",
            status: "submitted"
          }
        end
      else
        @submitted_logs = []
      end

      unless only_submitted
        @not_submitted_participants.each do |participant|
          @report_rows << {
            date: nil,
            participant_name: participant&.full_name.to_s.presence || "Unknown",
            participant_email: participant&.email.to_s.presence || "N/A",
            section_name: participant&.section&.name || "N/A",
            assignment_title: @assignment_title || "Assigned Tasks",
            status: "pending"
          }
        end
      else
        @not_submitted_participants = []
      end
    end

    # DB-paginated version for HTML format — avoids loading all records into memory.
    # KPIs are computed via COUNT queries; only the current page's records are instantiated.
    def fetch_assignment_reports_paginated
      set_report_filters
      base_query = build_assignment_report_base_query
      all_participants = build_all_participants_query

      # KPIs via COUNT queries (no record instantiation)
      submitted_participant_ids = base_query.distinct.pluck(:participant_id).compact
      @submitted_count = submitted_participant_ids.size
      not_submitted_query = all_participants.where.not(id: submitted_participant_ids)
      @pending_count = not_submitted_query.count
      @total_assigned_count = @submitted_count + @pending_count
      @participation_rate = (@total_assigned_count > 0) ? ((@submitted_count.to_f / @total_assigned_count) * 100).round(1) : 0.0

      # Participant Type Distributions for all 4 KPIs
      @submitted_by_type = if submitted_participant_ids.any?
                             current_institute.participants.where(id: submitted_participant_ids).group(:participant_type).count
                           else
                             {}
                           end
      @pending_by_type = not_submitted_query.group("participants.participant_type").count

      @total_assigned_by_type = {}
      @completion_rate_by_type = {}
      Participant.participant_types.keys.each do |ptype|
        sub = @submitted_by_type[ptype] || 0
        pnd = @pending_by_type[ptype] || 0
        tot = sub + pnd
        @total_assigned_by_type[ptype] = tot
        @completion_rate_by_type[ptype] = tot > 0 ? ((sub.to_f / tot) * 100).round(1) : 0.0
      end

      # Resolve assignment/section titles for display
      resolve_report_titles

      items_per_page = 15
      page_num = [ (params[:page] || 1).to_i, 1 ].max

      submitted_logs_count = base_query.count
      not_submitted_query = not_submitted_query.order("participants.id")
      pending_count = not_submitted_query.count

      only_submitted = (@selected_statuses == ["submitted"]) || (params[:submission_status] == "submitted" && @selected_statuses.blank?)
      only_pending = (@selected_statuses == ["not_submitted"]) || (params[:submission_status] == "not_submitted" && @selected_statuses.blank?)

      # Build paginated rows based on submission_status filter
      if only_pending
        @total_report_count = pending_count
        @pagy, paginated_participants = pagy(not_submitted_query, items: items_per_page)
        @paginated_rows = paginated_participants.map do |participant|
          {
            date: nil,
            participant_name: participant.full_name,
            participant_email: participant.email,
            section_name: participant.section&.name || "N/A",
            assignment_title: @assignment_title || "Assigned Tasks",
            status: "pending"
          }
        end
      elsif only_submitted
        @total_report_count = submitted_logs_count
        @pagy, paginated_logs = pagy(base_query.order(response_date: :desc), items: items_per_page)
        @paginated_rows = paginated_logs.map do |log|
          {
            date: log.response_date,
            participant_id: log.participant_id,
            assignment_id: log.assignment_id,
            participant_name: log.participant&.full_name.to_s.presence || "Unknown",
            participant_email: log.participant&.email.to_s.presence || "N/A",
            section_name: log.participant&.section&.name || "N/A",
            assignment_title: log.assignment&.title || "Assignment",
            status: "submitted"
          }
        end
      else
        @total_report_count = submitted_logs_count + pending_count
        @pagy = Pagy.new(count: @total_report_count, page: page_num, items: items_per_page)

        page_offset = @pagy.offset
        @paginated_rows = []

        if page_offset < submitted_logs_count
          logs_for_page = base_query.order(response_date: :desc).offset(page_offset).limit(items_per_page)
          logs_for_page.each do |log|
            @paginated_rows << {
              date: log.response_date,
              participant_id: log.participant_id,
              assignment_id: log.assignment_id,
              participant_name: log.participant&.full_name.to_s.presence || "Unknown",
              participant_email: log.participant&.email.to_s.presence || "N/A",
              section_name: log.participant&.section&.name || "N/A",
              assignment_title: log.assignment&.title || "Assignment",
              status: "submitted"
            }
          end

          if @paginated_rows.size < items_per_page && pending_count > 0
            needed = items_per_page - @paginated_rows.size
            pending_for_page = not_submitted_query.offset(0).limit(needed)
            pending_for_page.each do |participant|
              @paginated_rows << {
                date: nil,
                participant_name: participant.full_name,
                participant_email: participant.email,
                section_name: participant.section&.name || "N/A",
                assignment_title: @assignment_title || "Assigned Tasks",
                status: "pending"
              }
            end
          end
        else
          pending_offset = page_offset - submitted_logs_count
          pending_for_page = not_submitted_query.offset(pending_offset).limit(items_per_page)
          pending_for_page.each do |participant|
            @paginated_rows << {
              date: nil,
              participant_name: participant.full_name,
              participant_email: participant.email,
              section_name: participant.section&.name || "N/A",
              assignment_title: @assignment_title || "Assigned Tasks",
              status: "pending"
            }
          end
        end
      end

      # @report_rows is used for the "Showing X Records" badge in the view
      @report_rows = Array.new(@total_report_count)
    end

    # DB-paginated version for individual assignment reports HTML format.
    def fetch_individual_assignment_reports_paginated
      fetch_assignment_reports_paginated
    end

    def set_report_filters
      @date_range = params[:date_range].presence
      if @date_range == "custom"
        s_date = safe_parse_date(params[:start_date], 30.days.ago.to_date)
        e_date = safe_parse_date(params[:end_date], Date.current)
        @start_date = [s_date, e_date].min
        @end_date = [s_date, e_date].max
      else
        @start_date = safe_parse_date(params[:start_date], Date.current)
        @end_date = safe_parse_date(params[:end_date], Date.current)
      end
      @section_id = params[:section_id]
      @participant_id = params[:participant_id]
      @assignment_id = params[:assignment_id]

      # Multi-select support with backwards compatibility
      @selected_section_ids = parse_multiselect_param(params[:section_ids])
      if @selected_section_ids.empty? && @section_id.present? && @section_id != "all"
        @selected_section_ids = [@section_id.to_s]
      end

      @selected_assignment_ids = parse_multiselect_param(params[:assignment_ids])
      if @selected_assignment_ids.empty? && @assignment_id.present? && @assignment_id != "all"
        @selected_assignment_ids = [@assignment_id.to_s]
      end

      @selected_participant_ids = parse_multiselect_param(params[:participant_ids])
      if @selected_participant_ids.empty? && @participant_id.present? && @participant_id != "all"
        @selected_participant_ids = [@participant_id.to_s]
      end

      @selected_statuses = parse_multiselect_param(params[:submission_statuses])
      if @selected_statuses.empty? && params[:submission_status].present? && params[:submission_status] != "all"
        @selected_statuses = [params[:submission_status].to_s]
      end

      @available_assignments = current_institute.assignments.order(start_date: :desc, title: :asc)
      @available_sections = current_institute.sections.order(:name)
    end

    # Shared query builder for assignment report base query with date filtering.
    def build_assignment_report_base_query
      base_query = AssignmentResponseLog.includes(:participant, :assignment, participant: [ :section, :user ])
                                        .where(institute: current_institute)

      if params[:specific_date].present?
        exact_date = safe_parse_date(params[:specific_date], nil)
        base_query = base_query.where(response_date: exact_date.all_day) if exact_date
      elsif @date_range.present?
        base_query = case @date_range
        when "today"
                       base_query.where(response_date: Date.current.all_day)
        when "yesterday"
                       base_query.where(response_date: Date.yesterday.all_day)
        when "last_7_days"
                       base_query.where(response_date: 7.days.ago.beginning_of_day..Time.current)
        when "this_month"
                       base_query.where(response_date: Time.current.beginning_of_month..Time.current)
        when "custom"
                       start_d = [@start_date, @end_date].min
                       end_d = [@start_date, @end_date].max
                       base_query.where(response_date: start_d.beginning_of_day..end_d.end_of_day)
        else
                       base_query
        end
      end

      if @selected_section_ids.present? && !@selected_section_ids.include?("all")
        base_query = base_query.joins(participant: :section).where(sections: { id: @selected_section_ids })
      end

      if @selected_assignment_ids.present? && !@selected_assignment_ids.include?("all")
        base_query = base_query.where(assignment_id: @selected_assignment_ids)
      end

      if @selected_participant_ids.present? && !@selected_participant_ids.include?("all")
        base_query = base_query.where(participant_id: @selected_participant_ids)
      end

      if params[:search].present?
        query_str = "%#{params[:search].strip.downcase}%"
        base_query = base_query.left_outer_joins(participant: [ :user, :section ], assignment: [])
                               .where("LOWER(users.first_name) LIKE :q OR LOWER(users.last_name) LIKE :q OR LOWER(users.email) LIKE :q OR LOWER(sections.name) LIKE :q OR LOWER(assignments.title) LIKE :q OR LOWER(users.phone) LIKE :q OR LOWER(participants.phone_number) LIKE :q", q: query_str)
      end

      base_query
    end

    # Shared builder for all participants query, optionally filtered by section and search.
    def build_all_participants_query
      all_participants = current_institute.participants.includes(:section, :user).left_outer_joins(:user, :section)

      if @selected_section_ids.present? && !@selected_section_ids.include?("all")
        all_participants = all_participants.where("COALESCE(participants.section_id, users.section_id) IN (?)", @selected_section_ids)
      end

      if @selected_participant_ids.present? && !@selected_participant_ids.include?("all")
        all_participants = all_participants.where(id: @selected_participant_ids)
      end

      if params[:search].present?
        query_str = "%#{params[:search].strip.downcase}%"
        all_participants = all_participants.where("LOWER(users.first_name) LIKE :q OR LOWER(users.last_name) LIKE :q OR LOWER(users.email) LIKE :q OR LOWER(sections.name) LIKE :q OR LOWER(users.phone) LIKE :q OR LOWER(participants.phone_number) LIKE :q", q: query_str)
      end

      all_participants
    end

    # Resolve assignment/section titles for display labels.
    def resolve_report_titles
      if @selected_assignment_ids.present? && @selected_assignment_ids.size == 1 && !@selected_assignment_ids.include?("all")
        assignment = current_institute.assignments.find_by(id: @selected_assignment_ids.first)
        @assignment_title = assignment&.title
      elsif @assignment_id.present? && @assignment_id != "all"
        assignment = current_institute.assignments.find_by(id: @assignment_id)
        @assignment_title = assignment&.title
      end

      if @selected_section_ids.present? && @selected_section_ids.size == 1 && !@selected_section_ids.include?("all")
        section = current_institute.sections.find_by(id: @selected_section_ids.first)
        @section_title = section&.name
      elsif @section_id.present? && @section_id != "all"
        section = current_institute.sections.find_by(id: @section_id)
        @section_title = section&.name
      end

      if @selected_participant_ids.present? && @selected_participant_ids.size == 1 && !@selected_participant_ids.include?("all")
        participant = current_institute.participants.find_by(id: @selected_participant_ids.first)
        @participant_title = participant&.full_name
      elsif @participant_id.present? && @participant_id != "all"
        participant = current_institute.participants.find_by(id: @participant_id)
        @participant_title = participant&.full_name
      end
    end

    def self.ferrum_browser
      @ferrum_browser ||= Ferrum::Browser.new(
        timeout: 45,
        process_timeout: 30,
        window_size: [ 1200, 1600 ],
        browser_options: {
          "no-sandbox": nil,
          "disable-gpu": nil,
          "disable-dev-shm-usage": nil
        }
      )
    end

    def self.reset_ferrum_browser!
      if @ferrum_browser
        begin
          @ferrum_browser.quit
        rescue StandardError
          nil
        end
        @ferrum_browser = nil
      end
    end

    def generate_assignment_pdf_with_ferrum
      html_content = render_to_string(
        template: "institute_admin/reports/assignment_reports_pdf",
        formats: [ :html ],
        layout: false,
        locals: {
          current_institute: current_institute
        }
      )

      browser = self.class.ferrum_browser

      begin
        base64_html = Base64.strict_encode64(html_content)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(
          format: :A4,
          landscape: false,
          print_background: true
        )

        pdf_data = Base64.decode64(pdf_data) if pdf_data.present? && !pdf_data.start_with?("%PDF")
        pdf_data
      rescue StandardError => e
        Rails.logger.error("Ferrum PDF error: #{e.message}. Re-initializing Chrome instance...")
        self.class.reset_ferrum_browser!
        browser = self.class.ferrum_browser
        base64_html = Base64.strict_encode64(html_content)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(format: :A4, landscape: false, print_background: true)
        pdf_data = Base64.decode64(pdf_data) if pdf_data.present? && !pdf_data.start_with?("%PDF")
        pdf_data
      end
    end

    def fetch_section_feedback_reports
      base_query = TrainingProgramFeedback.includes(:participant, :training_program, participant: :section)
                                        .where(training_programs: { institute_id: current_institute.id })

      # Apply date filters
      base_query = case @date_range
      when "today"
                    base_query.where(created_at: Date.current.all_day)
      when "yesterday"
                    base_query.where(created_at: Date.yesterday.all_day)
      when "last_7_days"
                    base_query.where(created_at: 7.days.ago.beginning_of_day..Time.current)
      when "this_month"
                    base_query.where(created_at: Time.current.beginning_of_month..Time.current)
      when "custom"
                    base_query.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
      else
                    base_query.where(created_at: Date.current.all_day)
      end

      # Apply section filter if selected
      if @section_id.present? && @section_id != "all"
        base_query = base_query.joins(participant: :section)
                              .where(sections: { id: @section_id })
      end

      @submitted_feedbacks = base_query.order(created_at: :desc)

      # Get all participants who should have submitted feedback
      all_participants = if @section_id.present? && @section_id != "all"
                         current_institute.participants.includes(:section).where(section_id: @section_id)
      else
                         current_institute.participants.includes(:section)
      end

      # Get participants who haven't submitted feedback
      submitted_participant_ids = @submitted_feedbacks.pluck(:participant_id).uniq
      @not_submitted_participants = all_participants.where.not(id: submitted_participant_ids)

      # Clear the data that's not needed based on submission status
      if params[:submission_status] == "submitted"
        @not_submitted_participants = []
      elsif params[:submission_status] == "not_submitted"
        @submitted_feedbacks = []
      end
    end

    def fetch_individual_assignment_reports
      fetch_assignment_reports
    end

    def fetch_individual_feedback_reports
      # Only proceed if a participant is selected
      return if @participant_id.blank?

      participant = current_institute.participants.find(@participant_id)

      if params[:submission_status] == "submitted"
        # Get submitted feedbacks for the participant
        base_query = TrainingProgramFeedback.includes(:training_program)
                                        .where(participant_id: @participant_id)

        # Apply date filters
        base_query = case @date_range
        when "today"
                      base_query.where(created_at: Date.current.all_day)
        when "yesterday"
                      base_query.where(created_at: Date.yesterday.all_day)
        when "last_7_days"
                      base_query.where(created_at: 7.days.ago.beginning_of_day..Time.current)
        when "this_month"
                      base_query.where(created_at: Time.current.beginning_of_month..Time.current)
        when "custom"
                      base_query.where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
        else
                      base_query.where(created_at: Date.current.all_day)
        end

        # Apply training program filter if selected
        if @training_program_id.present? && @training_program_id != "all"
          base_query = base_query.where(training_program_id: @training_program_id)
        end

        @submitted_feedbacks = base_query.order(created_at: :desc)
        @not_submitted_training_programs = []
      else
        # Get all training programs the participant should have given feedback for
        available_programs = participant.all_training_programs
                                    .where(institute: current_institute)
                                    .where("end_date >= ?", @start_date)
                                    .where("start_date <= ?", @end_date)

        # Filter by specific training program if selected
        if @training_program_id.present? && @training_program_id != "all"
          available_programs = available_programs.where(id: @training_program_id)
        end

        # Find which training programs haven't received feedback
        submitted_program_ids = TrainingProgramFeedback.where(participant_id: @participant_id)
                                                   .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
                                                   .pluck(:training_program_id)
                                                   .uniq

        @not_submitted_training_programs = available_programs.reject { |tp| submitted_program_ids.include?(tp.id) }
        @submitted_feedbacks = []
      end
    end

    def generate_assignment_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [ "#", "Date", "Participant Name", "Email", "Section", "Assignment Title", "Status" ]

        if @report_rows.present?
          @report_rows.each_with_index do |row, index|
            csv << [
              index + 1,
              row[:date].respond_to?(:strftime) ? row[:date].strftime("%Y-%m-%d") : (row[:date].presence || "N/A"),
              row[:participant_name],
              row[:participant_email],
              row[:section_name],
              row[:assignment_title],
              row[:status].to_s.titleize
            ]
          end
        end
      end
    end

    def generate_section_feedback_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        if params[:submission_status] == "submitted"
          # Generate submitted feedbacks CSV
          csv << [ "#", "Date", "Participant", "Section", "Training Program", "Rating", "Content" ]
          @submitted_feedbacks.each_with_index do |feedback, index|
            csv << [
              index + 1,
              feedback.created_at.strftime("%B %d, %Y"),
              feedback.participant&.full_name.to_s,
              feedback.participant&.section&.name || "N/A",
              feedback.training_program&.title.to_s,
              feedback.rating,
              feedback.content
            ]
          end
        else
          # Generate not submitted feedbacks CSV
          csv << [ "#", "Participant", "Section", "Email" ]
          @not_submitted_participants.each_with_index do |participant, index|
            csv << [
              index + 1,
              participant&.full_name.to_s,
              participant&.section&.name || "N/A",
              participant&.email.to_s
            ]
          end
        end
      end
    end

    def generate_individual_assignment_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        csv << [ "#", "Date", "Participant", "Email", "Section", "Assignment", "Status" ]

        (@report_rows || []).each_with_index do |row, index|
          csv << [
            index + 1,
            row[:date].respond_to?(:strftime) ? row[:date].strftime("%B %d, %Y") : (row[:date].presence || "Pending"),
            row[:participant_name],
            row[:participant_email],
            row[:section_name],
            row[:assignment_title],
            row[:status].to_s.titleize
          ]
        end
      end
    end

    def generate_individual_feedback_csv
      require "csv"

      CSV.generate(headers: true) do |csv|
        if params[:submission_status] == "submitted"
          # Generate submitted feedbacks CSV
          csv << [ "Date", "Training Program", "Rating", "Feedback" ]

          @submitted_feedbacks.each do |feedback|
            csv << [
              feedback.created_at.strftime("%B %d, %Y"),
              feedback.training_program.title,
              feedback.rating,
              feedback.content
            ]
          end
        else
          # Generate not submitted training programs CSV
          csv << [ "Training Program", "Start Date", "End Date", "Status" ]

          @not_submitted_training_programs.each do |tp|
            csv << [
              tp.title,
              tp.start_date.strftime("%B %d, %Y"),
              tp.end_date.strftime("%B %d, %Y"),
              tp.status
            ]
          end
        end
      end
    end

    def set_consolidated_report_filters
      @available_assignments = current_institute.assignments.active.order(start_date: :desc, title: :asc)
      @available_sections = current_institute.sections.active.order(:name)
      @available_participant_types = Participant.participant_types.keys

      @selected_assignment_ids = parse_multiselect_param(params[:assignment_ids])
      @selected_section_ids = parse_multiselect_param(params[:section_ids])
      @selected_participant_types = parse_multiselect_param(params[:participant_types])

      participants_scope = current_institute.participants.includes(:user, :section)
      if @selected_section_ids.present?
        participants_scope = participants_scope.where(section_id: @selected_section_ids)
      end
      if @selected_participant_types.present?
        participants_scope = participants_scope.where(participant_type: @selected_participant_types)
      end
      @available_participants = participants_scope.joins(:user).order("users.first_name ASC, users.last_name ASC")
      @selected_participant_ids = parse_multiselect_param(params[:participant_ids])

      target_asg_ids = @selected_assignment_ids.presence || @available_assignments.pluck(:id)
      aq_ids = AssignmentQuestion.where(assignment_id: target_asg_ids).pluck(:question_id)
      aqs_ids = AssignmentQuestionSet.where(assignment_id: target_asg_ids)
                                     .joins(question_set: :question_set_items)
                                     .pluck("question_set_items.question_id")
      all_q_ids = (aq_ids + aqs_ids).uniq
      @available_questions = current_institute.questions.where(id: all_q_ids).order(:title)
      if @available_questions.empty?
        @available_questions = current_institute.questions.active.order(:title)
      end
      @selected_question_ids = parse_multiselect_param(params[:question_ids])

      @selected_statuses = parse_multiselect_param(params[:submission_statuses])
      @selected_statuses = [ "submitted", "pending" ] if @selected_statuses.blank?

      @date_range = params[:date_range].presence || "today"
      set_consolidated_date_range_window(@date_range)
      @today_active_question_ids = AssignmentResponse.joins(:participant)
                                                     .where(participants: { institute_id: current_institute.id })
                                                     .where(response_date: Date.current.all_day)
                                                     .distinct
                                                     .pluck(:question_id)
    end

    def safe_parse_date(val, fallback = Date.current)
      return fallback if val.blank?
      Date.parse(val.to_s)
    rescue Date::Error, ArgumentError, TypeError
      fallback
    end

    def parse_multiselect_param(param)
      return [] if param.blank?
      if param.is_a?(Array)
        param.reject(&:blank?).map(&:to_s)
      elsif param.is_a?(String)
        param.split(",").map(&:strip).reject(&:blank?)
      else
        []
      end
    end

    def set_consolidated_date_range_window(range = @date_range)
      case range
      when "today"
        @start_date = Date.current
        @end_date = Date.current
      when "yesterday"
        @start_date = Date.yesterday
        @end_date = Date.yesterday
      when "last_7_days"
        @start_date = 6.days.ago.to_date
        @end_date = Date.current
      when "this_month"
        @start_date = Date.current.beginning_of_month
        @end_date = Date.current
      when "custom"
        s_date = safe_parse_date(params[:start_date], 30.days.ago.to_date)
        e_date = safe_parse_date(params[:end_date], Date.current)
        @start_date = [s_date, e_date].min
        @end_date = [s_date, e_date].max
      else # "all_time"
        @start_date = nil
        @end_date = nil
      end
    rescue StandardError
      @start_date = nil
      @end_date = nil
    end

    def build_consolidated_report_base_query
      base_query = AssignmentResponse.joins(:assignment, :question, participant: :user)
                                     .joins("LEFT OUTER JOIN sections ON sections.id = COALESCE(participants.section_id, users.section_id)")
                                     .where(participants: { institute_id: current_institute.id })
                                     .where(assignments: { institute_id: current_institute.id })

      if @selected_assignment_ids.present?
        base_query = base_query.where(assignment_id: @selected_assignment_ids)
      end

      if @selected_section_ids.present?
        base_query = base_query.where("COALESCE(participants.section_id, users.section_id) IN (?)", @selected_section_ids)
      end

      if @selected_participant_ids.present?
        base_query = base_query.where(participant_id: @selected_participant_ids)
      end

      if @selected_participant_types.present?
        base_query = base_query.where(participants: { participant_type: @selected_participant_types })
      end

      if @selected_question_ids.present?
        base_query = base_query.where(question_id: @selected_question_ids)
      end

      if @start_date.present? && @end_date.present?
        s_d = [@start_date, @end_date].min
        e_d = [@start_date, @end_date].max
        base_query = base_query.where(response_date: s_d.beginning_of_day..e_d.end_of_day)
      end

      if params[:search].present?
        q_str = "%#{params[:search].strip.downcase}%"
        base_query = base_query.where(
          "LOWER(users.first_name) LIKE :q OR LOWER(users.last_name) LIKE :q OR LOWER(users.email) LIKE :q OR LOWER(sections.name) LIKE :q OR LOWER(assignments.title) LIKE :q OR LOWER(questions.title) LIKE :q OR LOWER(assignment_responses.answer) LIKE :q",
          q: q_str
        )
      end

      base_query
    end

    def build_consolidated_pending_rows(base_query)
      return [] unless @selected_statuses.include?("pending")

      target_assignments = if @selected_assignment_ids.present?
                             current_institute.assignments.where(id: @selected_assignment_ids)
                           else
                             current_institute.assignments.active
                           end

      target_participants = if @selected_participant_ids.present?
                              current_institute.participants.includes(:user, :section).where(id: @selected_participant_ids)
                            elsif @selected_section_ids.present?
                              current_institute.participants.includes(:user, :section)
                                               .left_outer_joins(:user)
                                               .where("COALESCE(participants.section_id, users.section_id) IN (?)", @selected_section_ids)
                            else
                              current_institute.participants.includes(:user, :section)
                            end

      if @selected_participant_types.present?
        target_participants = target_participants.where(participant_type: @selected_participant_types)
      end

      submitted_pairs = Set.new(base_query.distinct.pluck(:participant_id, :assignment_id))

      assignment_ids = target_assignments.pluck(:id)
      individual_assignments_map = AssignmentParticipant.where(assignment_id: assignment_ids)
                                                        .pluck(:assignment_id, :participant_id)
                                                        .group_by(&:first)
                                                        .transform_values { |pairs| Set.new(pairs.map(&:second)) }

      section_assignments_map = AssignmentSection.where(assignment_id: assignment_ids)
                                                 .pluck(:assignment_id, :section_id)
                                                 .group_by(&:first)
                                                 .transform_values { |pairs| Set.new(pairs.map(&:second)) }

      pending_rows = []
      search_q = params[:search].to_s.strip.downcase

      target_participants.each do |p|
        p_name = p.full_name.to_s
        p_email = p.email.to_s
        p_sec = p.section&.name.to_s.presence || "N/A"
        p_sec_id = p.section_id.presence || p.user&.section_id

        target_assignments.each do |asg|
          asg_title = asg.title.to_s
          is_assigned = if asg.assignment_type == "individual"
                          individual_assignments_map[asg.id]&.include?(p.id)
                        else
                          p_sec_id.present? && (
                            (asg.section_id.present? && asg.section_id == p_sec_id) ||
                            section_assignments_map[asg.id]&.include?(p_sec_id)
                          )
                        end

          next unless is_assigned
          next if submitted_pairs.include?([p.id, asg.id])

          if search_q.present?
            match = p_name.downcase.include?(search_q) ||
                    p_email.downcase.include?(search_q) ||
                    p_sec.downcase.include?(search_q) ||
                    asg_title.downcase.include?(search_q)
            next unless match
          end

          pending_rows << {
            id: nil,
            date: nil,
            participant_id: p.id,
            participant_name: p_name.presence || "N/A",
            participant_email: p_email.presence || "N/A",
            participant_type: p.participant_type,
            section_name: p_sec,
            assignment_id: asg.id,
            assignment_title: asg_title.presence || "Assignment",
            question_id: nil,
            question_title: "Pending Submission",
            question_type: "-",
            answer: "No submission recorded",
            status: "pending",
            submitted_at: nil
          }
        end
      end

      pending_rows
    end

    def fetch_consolidated_response_reports
      set_consolidated_report_filters
      base_query = build_consolidated_report_base_query
      pending_rows = build_consolidated_pending_rows(base_query)

      @report_rows = []

      if @selected_statuses.include?("submitted")
        submitted_responses = base_query.includes(:question, :assignment, participant: [ :user, :section ])
                                         .order("assignment_responses.response_date DESC, assignment_responses.id DESC")
        submitted_responses.each do |resp|
          @report_rows << format_consolidated_response_row(resp)
        end
      end

      if @selected_statuses.include?("pending")
        @report_rows.concat(pending_rows)
      end

      calculate_consolidated_kpis(base_query, pending_rows)
    end

    def fetch_consolidated_response_reports_paginated
      set_consolidated_report_filters
      base_query = build_consolidated_report_base_query
      pending_rows_list = build_consolidated_pending_rows(base_query)

      submitted_count = @selected_statuses.include?("submitted") ? base_query.count : 0
      pending_count = @selected_statuses.include?("pending") ? pending_rows_list.size : 0

      @total_report_count = submitted_count + pending_count
      page_num = [ (params[:page] || 1).to_i, 1 ].max
      items_per_page = 25

      @pagy = Pagy.new(count: @total_report_count, page: page_num, items: items_per_page)
      page_offset = @pagy.offset
      @paginated_rows = []

      if page_offset < submitted_count
        responses_for_page = base_query.includes(:question, :assignment, participant: [ :user, :section ])
                                       .order("assignment_responses.response_date DESC, assignment_responses.id DESC")
                                       .offset(page_offset)
                                       .limit(items_per_page)

        responses_for_page.each do |resp|
          @paginated_rows << format_consolidated_response_row(resp)
        end

        if @paginated_rows.size < items_per_page && pending_count > 0
          needed = items_per_page - @paginated_rows.size
          @paginated_rows.concat(pending_rows_list.slice(0, needed) || [])
        end
      else
        pending_offset = page_offset - submitted_count
        @paginated_rows.concat(pending_rows_list.slice(pending_offset, items_per_page) || [])
      end

      calculate_consolidated_kpis(base_query, pending_rows_list)
      @report_rows = Array.new(@total_report_count)
    end

    def calculate_consolidated_kpis(base_query, pending_rows)
      submitted_participant_ids = base_query.distinct.pluck(:participant_id)
      pending_participant_ids = pending_rows.map { |r| r[:participant_id] }.compact.uniq
      all_filtered_participant_ids = (submitted_participant_ids + pending_participant_ids).uniq

      @filtered_participants_count = all_filtered_participant_ids.size

      if all_filtered_participant_ids.present?
        @participant_type_distribution = current_institute.participants
                                                          .where(id: all_filtered_participant_ids)
                                                          .group(:participant_type)
                                                          .count
      else
        @participant_type_distribution = {}
      end

      submitted_asg_ids = base_query.distinct.pluck(:assignment_id)
      pending_asg_ids = pending_rows.map { |r| r[:assignment_id] }.compact.uniq
      all_filtered_asg_ids = (submitted_asg_ids + pending_asg_ids).uniq
      @total_filtered_assignments = all_filtered_asg_ids.size

      @total_submitted_responses = base_query.count
      @total_pending_count = pending_rows.size

      @submitted_participants_count = submitted_participant_ids.size

      total_assigned_slots = @submitted_participants_count + @total_pending_count
      @overall_completion_rate = if total_assigned_slots > 0
        ((@submitted_participants_count.to_f / total_assigned_slots) * 100).round(1)
      else
        0.0
      end
    end

    def format_consolidated_response_row(resp)
      answer_text = if resp.answer.present?
                      resp.answer
                    elsif resp.selected_options.is_a?(Array)
                      resp.selected_options.reject(&:blank?).join(", ")
                    else
                      resp.selected_options.to_s
                    end

      {
        id: resp.id,
        date: resp.response_date,
        participant_id: resp.participant_id,
        participant_name: resp.participant&.full_name || "N/A",
        participant_email: resp.participant&.email || "N/A",
        participant_type: resp.participant&.participant_type,
        section_name: resp.participant&.section&.name || "N/A",
        assignment_id: resp.assignment_id,
        assignment_title: resp.assignment&.title || "Assignment",
        question_id: resp.question_id,
        question_title: resp.question&.title || "Question",
        question_type: resp.question&.question_type || "text",
        answer: answer_text.presence || "-",
        status: "submitted",
        submitted_at: resp.submitted_at || resp.created_at
      }
    end

    def generate_consolidated_response_excel
      rows = @report_rows || []

      xml = String.new
      xml << %{<?xml version="1.0" encoding="UTF-8"?>\n}
      xml << %{<?mso-application progid="Excel.Sheet"?>\n}
      xml << %{<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n}
      xml << %{ xmlns:o="urn:schemas-microsoft-com:office:office"\n}
      xml << %{ xmlns:x="urn:schemas-microsoft-com:office:excel"\n}
      xml << %{ xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"\n}
      xml << %{ xmlns:html="http://www.w3.org/TR/REC-html40">\n}
      xml << %{ <Styles>\n}
      xml << %{  <Style ss:ID="Header">\n}
      xml << %{   <Font ss:Bold="1" ss:Color="#FFFFFF" ss:FontName="Segoe UI" ss:Size="11"/>\n}
      xml << %{   <Interior ss:Color="#1E293B" ss:Pattern="Solid"/>\n}
      xml << %{   <Alignment ss:Vertical="Center" ss:WrapText="1"/>\n}
      xml << %{  </Style>\n}
      xml << %{  <Style ss:ID="RowSubmitted">\n}
      xml << %{   <Font ss:Color="#0F172A" ss:FontName="Segoe UI" ss:Size="10"/>\n}
      xml << %{   <Alignment ss:Vertical="Center" ss:WrapText="1"/>\n}
      xml << %{  </Style>\n}
      xml << %{  <Style ss:ID="BadgeSubmitted">\n}
      xml << %{   <Font ss:Bold="1" ss:Color="#15803D" ss:FontName="Segoe UI" ss:Size="10"/>\n}
      xml << %{   <Interior ss:Color="#DCFCE7" ss:Pattern="Solid"/>\n}
      xml << %{   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>\n}
      xml << %{  </Style>\n}
      xml << %{  <Style ss:ID="BadgePending">\n}
      xml << %{   <Font ss:Bold="1" ss:Color="#B45309" ss:FontName="Segoe UI" ss:Size="10"/>\n}
      xml << %{   <Interior ss:Color="#FEF3C7" ss:Pattern="Solid"/>\n}
      xml << %{   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>\n}
      xml << %{  </Style>\n}
      xml << %{ </Styles>\n}

      # WORKSHEET 1: Detailed Responses
      xml << %{ <Worksheet ss:Name="Consolidated Responses">\n}
      xml << %{  <Table>\n}
      xml << %{   <Column ss:Width="40"/>\n}
      xml << %{   <Column ss:Width="90"/>\n}
      xml << %{   <Column ss:Width="160"/>\n}
      xml << %{   <Column ss:Width="180"/>\n}
      xml << %{   <Column ss:Width="110"/>\n}
      xml << %{   <Column ss:Width="170"/>\n}
      xml << %{   <Column ss:Width="220"/>\n}
      xml << %{   <Column ss:Width="100"/>\n}
      xml << %{   <Column ss:Width="220"/>\n}
      xml << %{   <Column ss:Width="90"/>\n}
      xml << %{   <Column ss:Width="120"/>\n}

      headers = [ "#", "Response Date", "Participant Name", "Participant Type", "Email", "Section", "Assignment Title", "Question", "Question Type", "Answer / Response", "Status", "Submitted At" ]
      xml << %{   <Row ss:Height="26" ss:StyleID="Header">\n}
      headers.each do |h|
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(h)}</Data></Cell>\n}
      end
      xml << %{   </Row>\n}

      rows.each_with_index do |row, idx|
        status_style = row[:status] == "submitted" ? "BadgeSubmitted" : "BadgePending"
        date_str = row[:date].present? ? row[:date].strftime("%Y-%m-%d") : "-"
        time_str = row[:submitted_at].present? ? row[:submitted_at].strftime("%I:%M %p") : "-"

        xml << %{   <Row ss:Height="22" ss:StyleID="RowSubmitted">\n}
        xml << %{    <Cell><Data ss:Type="Number">#{idx + 1}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(date_str)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:participant_name].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:participant_type].to_s.titleize)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:participant_email].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:section_name].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:assignment_title].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:question_title].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:question_type].to_s.humanize)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:answer].to_s)}</Data></Cell>\n}
        xml << %{    <Cell ss:StyleID="#{status_style}"><Data ss:Type="String">#{CGI.escapeHTML(row[:status].to_s.titleize)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(time_str)}</Data></Cell>\n}
        xml << %{   </Row>\n}
      end

      xml << %{  </Table>\n}
      xml << %{ </Worksheet>\n}

      # WORKSHEET 2: Participant Summary Matrix
      xml << %{ <Worksheet ss:Name="Participant Summary">\n}
      xml << %{  <Table>\n}
      xml << %{   <Column ss:Width="40"/>\n}
      xml << %{   <Column ss:Width="160"/>\n}
      xml << %{   <Column ss:Width="180"/>\n}
      xml << %{   <Column ss:Width="110"/>\n}
      xml << %{   <Column ss:Width="170"/>\n}
      xml << %{   <Column ss:Width="120"/>\n}
      xml << %{   <Column ss:Width="100"/>\n}

      summary_headers = [ "#", "Participant Name", "Email", "Section", "Assignment Title", "Questions Answered", "Status" ]
      xml << %{   <Row ss:Height="26" ss:StyleID="Header">\n}
      summary_headers.each do |h|
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(h)}</Data></Cell>\n}
      end
      xml << %{   </Row>\n}

      grouped_summary = rows.group_by { |r| [ r[:participant_id], r[:assignment_id] ] }
      summary_idx = 0
      grouped_summary.each do |_, group_items|
        summary_idx += 1
        first_item = group_items.first
        answered_count = group_items.count { |r| r[:status] == "submitted" }
        overall_status = answered_count > 0 ? "Submitted" : "Pending"
        status_style = overall_status == "Submitted" ? "BadgeSubmitted" : "BadgePending"

        xml << %{   <Row ss:Height="22" ss:StyleID="RowSubmitted">\n}
        xml << %{    <Cell><Data ss:Type="Number">#{summary_idx}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(first_item[:participant_name].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(first_item[:participant_email].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(first_item[:section_name].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(first_item[:assignment_title].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="Number">#{answered_count}</Data></Cell>\n}
        xml << %{    <Cell ss:StyleID="#{status_style}"><Data ss:Type="String">#{CGI.escapeHTML(overall_status)}</Data></Cell>\n}
        xml << %{   </Row>\n}
      end

      xml << %{  </Table>\n}
      xml << %{ </Worksheet>\n}
      xml << %{</Workbook>\n}

      xml
    end

    def generate_consolidated_response_csv
      require "csv"
      rows = @report_rows || []

      CSV.generate(headers: true) do |csv|
        csv << [ "#", "Response Date", "Participant Name", "Participant Type", "Email", "Section", "Assignment Title", "Question", "Question Type", "Answer / Response", "Status", "Submitted At" ]

        rows.each_with_index do |row, index|
          csv << [
            index + 1,
            row[:date].present? ? row[:date].strftime("%Y-%m-%d") : "-",
            row[:participant_name],
            row[:participant_type].to_s.titleize,
            row[:participant_email],
            row[:section_name],
            row[:assignment_title],
            row[:question_title],
            row[:question_type].to_s.humanize,
            row[:answer],
            row[:status].to_s.titleize,
            row[:submitted_at].present? ? row[:submitted_at].strftime("%I:%M %p") : "-"
          ]
        end
      end
    end

    def set_consolidated_matrix_filters
      @available_assignments = current_institute.assignments.active.order(:title)
      @available_sections = current_institute.sections.active.order(:name)
      @available_participant_types = Participant.participant_types.keys

      @selected_assignment_ids = parse_multiselect_param(params[:assignment_ids])
      @selected_section_ids = parse_multiselect_param(params[:section_ids])
      @selected_participant_types = parse_multiselect_param(params[:participant_types])

      participants_scope = current_institute.participants.includes(:user, :section)
      if @selected_section_ids.present?
        participants_scope = participants_scope.where(section_id: @selected_section_ids)
      end
      if @selected_participant_types.present?
        participants_scope = participants_scope.where(participant_type: @selected_participant_types)
      end
      @available_participants = participants_scope.joins(:user).order("users.first_name ASC, users.last_name ASC")
      @selected_participant_ids = parse_multiselect_param(params[:participant_ids])

      target_asg_ids = @selected_assignment_ids.presence || @available_assignments.pluck(:id)
      aq_ids = AssignmentQuestion.where(assignment_id: target_asg_ids).pluck(:question_id)
      aqs_ids = AssignmentQuestionSet.where(assignment_id: target_asg_ids)
                                     .joins(question_set: :question_set_items)
                                     .pluck("question_set_items.question_id")
      all_q_ids = (aq_ids + aqs_ids).uniq
      @available_questions = current_institute.questions.where(id: all_q_ids).order(:title)
      if @available_questions.empty?
        @available_questions = current_institute.questions.active.order(:title)
      end
      @selected_question_ids = parse_multiselect_param(params[:question_ids])

      @selected_statuses = parse_multiselect_param(params[:submission_statuses])
      @selected_statuses = [ "submitted", "pending" ] if @selected_statuses.empty?

      @date_range = params[:date_range].presence || "today"
      set_consolidated_date_range_window(@date_range)
      @search = params[:search].to_s.strip
      @today_active_question_ids = AssignmentResponse.joins(:participant)
                                                     .where(participants: { institute_id: current_institute.id })
                                                     .where(response_date: Date.current.all_day)
                                                     .distinct
                                                     .pluck(:question_id)

      resolve_matrix_questions
    end

    def resolve_matrix_questions
      target_assignments = if @selected_assignment_ids.present?
                             current_institute.assignments.where(id: @selected_assignment_ids)
                           else
                             current_institute.assignments.active
                           end

      assignment_ids = target_assignments.pluck(:id)
      questions_map = {}

      # 1. Questions via AssignmentQuestion
      aqs = AssignmentQuestion.where(assignment_id: assignment_ids)
                              .includes(:question, :assignment)
                              .order("assignment_questions.assignment_id ASC, assignment_questions.order_number ASC NULLS LAST, assignment_questions.id ASC")

      aqs.each do |aq|
        q = aq.question
        next unless q
        questions_map[q.id] ||= {
          id: q.id,
          title: q.title,
          question_type: q.question_type,
          assignment_ids: Set.new,
          assignment_titles: Set.new,
          order: aq.order_number || 999
        }
        questions_map[q.id][:assignment_ids] << aq.assignment_id
        questions_map[q.id][:assignment_titles] << aq.assignment&.title
      end

      # 2. Questions via AssignmentQuestionSet
      aq_sets = AssignmentQuestionSet.where(assignment_id: assignment_ids)
                                     .includes(question_set: { question_set_items: :question }, assignment: {})
      aq_sets.each do |aqs_item|
        aqs_item.question_set&.question_set_items&.each do |qsi|
          q = qsi.question
          next unless q
          questions_map[q.id] ||= {
            id: q.id,
            title: q.title,
            question_type: q.question_type,
            assignment_ids: Set.new,
            assignment_titles: Set.new,
            order: qsi.position || 999
          }
          questions_map[q.id][:assignment_ids] << aqs_item.assignment_id
          questions_map[q.id][:assignment_titles] << aqs_item.assignment&.title
        end
      end

      questions_map.each_value do |q_data|
        q_data[:assignments_text] = q_data[:assignment_titles].to_a.compact.join(", ")
      end

      # Filter matrix questions if specific questions are selected
      if @selected_question_ids.present?
        sel_q_set = Set.new(@selected_question_ids.map(&:to_i))
        questions_map.select! { |q_id, _| sel_q_set.include?(q_id) }
      end

      @matrix_questions = questions_map.values.sort_by { |q| [ q[:order], q[:id] ] }
    end

    def build_consolidated_matrix_base_query
      base_query = AssignmentResponseLog.joins(:participant, :assignment)
                                        .joins("INNER JOIN users ON users.id = participants.user_id")
                                        .joins("LEFT OUTER JOIN sections ON sections.id = COALESCE(participants.section_id, users.section_id)")
                                        .where(assignment_response_logs: { institute_id: current_institute.id })
                                        .where(participants: { institute_id: current_institute.id })
                                        .where(assignments: { institute_id: current_institute.id })

      if @selected_assignment_ids.present?
        base_query = base_query.where(assignment_id: @selected_assignment_ids)
      end

      if @selected_section_ids.present?
        base_query = base_query.where("COALESCE(participants.section_id, users.section_id) IN (?)", @selected_section_ids)
      end

      if @selected_participant_ids.present?
        base_query = base_query.where(participant_id: @selected_participant_ids)
      end

      if @selected_participant_types.present?
        base_query = base_query.where(participants: { participant_type: @selected_participant_types })
      end

      if @start_date.present? && @end_date.present?
        s_d = [@start_date, @end_date].min
        e_d = [@start_date, @end_date].max
        base_query = base_query.where(response_date: s_d.beginning_of_day..e_d.end_of_day)
      end

      if params[:search].present?
        q_str = "%#{params[:search].strip.downcase}%"
        # Match user details, section, assignment title, or questions assigned
        matched_asg_ids = AssignmentQuestion.joins(:question)
                                            .where(questions: { institute_id: current_institute.id })
                                            .where("LOWER(questions.title) LIKE :q", q: q_str)
                                            .pluck(:assignment_id)
        matched_asg_ids += AssignmentQuestionSet.joins(question_set: { question_set_items: :question })
                                                .where("LOWER(questions.title) LIKE :q", q: q_str)
                                                .pluck(:assignment_id)
        matched_asg_ids.uniq!

        if matched_asg_ids.present?
          base_query = base_query.where(
            "LOWER(users.first_name) LIKE :q OR LOWER(users.last_name) LIKE :q OR LOWER(users.email) LIKE :q OR LOWER(sections.name) LIKE :q OR LOWER(assignments.title) LIKE :q OR assignments.id IN (:asg_ids)",
            q: q_str,
            asg_ids: matched_asg_ids
          )
        else
          base_query = base_query.where(
            "LOWER(users.first_name) LIKE :q OR LOWER(users.last_name) LIKE :q OR LOWER(users.email) LIKE :q OR LOWER(sections.name) LIKE :q OR LOWER(assignments.title) LIKE :q",
            q: q_str
          )
        end
      end

      base_query
    end

    def build_consolidated_matrix_pending_rows(base_query)
      return [] unless @selected_statuses.include?("pending")

      target_assignments = if @selected_assignment_ids.present?
                             current_institute.assignments.where(id: @selected_assignment_ids)
                           else
                             current_institute.assignments.active
                           end

      target_participants = if @selected_participant_ids.present?
                              current_institute.participants.includes(:user, :section).where(id: @selected_participant_ids)
                            elsif @selected_section_ids.present?
                              current_institute.participants.includes(:user, :section)
                                               .left_outer_joins(:user)
                                               .where("COALESCE(participants.section_id, users.section_id) IN (?)", @selected_section_ids)
                            else
                              current_institute.participants.includes(:user, :section)
                            end

      if @selected_participant_types.present?
        target_participants = target_participants.where(participant_type: @selected_participant_types)
      end

      submitted_pairs = Set.new(base_query.distinct.pluck(:participant_id, :assignment_id))

      assignment_ids = target_assignments.pluck(:id)
      individual_assignments_map = AssignmentParticipant.where(assignment_id: assignment_ids)
                                                        .pluck(:assignment_id, :participant_id)
                                                        .group_by(&:first)
                                                        .transform_values { |pairs| Set.new(pairs.map(&:second)) }

      section_assignments_map = AssignmentSection.where(assignment_id: assignment_ids)
                                                 .pluck(:assignment_id, :section_id)
                                                 .group_by(&:first)
                                                 .transform_values { |pairs| Set.new(pairs.map(&:second)) }

      pending_rows = []
      search_q = params[:search].to_s.strip.downcase

      target_participants.each do |p|
        p_name = p.full_name.to_s
        p_email = p.email.to_s
        p_sec = p.section&.name.to_s.presence || "N/A"
        p_sec_id = p.section_id.presence || p.user&.section_id

        target_assignments.each do |asg|
          asg_title = asg.title.to_s
          is_assigned = if asg.assignment_type == "individual"
                          individual_assignments_map[asg.id]&.include?(p.id)
                        else
                          p_sec_id.present? && (
                            (asg.section_id.present? && asg.section_id == p_sec_id) ||
                            section_assignments_map[asg.id]&.include?(p_sec_id)
                          )
                        end

          next unless is_assigned
          next if submitted_pairs.include?([p.id, asg.id])

          if search_q.present?
            match = p_name.downcase.include?(search_q) ||
                    p_email.downcase.include?(search_q) ||
                    p_sec.downcase.include?(search_q) ||
                    asg_title.downcase.include?(search_q)
            next unless match
          end

          pending_rows << {
            id: nil,
            date: nil,
            participant_id: p.id,
            participant_name: p_name.presence || "N/A",
            participant_email: p_email.presence || "N/A",
            participant_type: p.participant_type,
            section_name: p_sec,
            assignment_id: asg.id,
            assignment_title: asg_title.presence || "Assignment",
            status: "pending",
            submitted_at: nil,
            answers: {}
          }
        end
      end

      pending_rows
    end

    def fetch_consolidated_matrix_reports
      set_consolidated_matrix_filters
      base_query = build_consolidated_matrix_base_query
      pending_rows = build_consolidated_matrix_pending_rows(base_query)

      @matrix_rows = []

      if @selected_statuses.include?("submitted")
        logs = base_query.includes(:assignment, participant: [ :user, :section ])
                         .order("assignment_response_logs.response_date DESC, assignment_response_logs.id DESC")

        load_matrix_answers_for_logs(logs).each do |formatted_row|
          @matrix_rows << formatted_row
        end
      end

      if @selected_statuses.include?("pending")
        @matrix_rows.concat(pending_rows)
      end

      calculate_matrix_kpis(base_query, pending_rows)
    end

    def fetch_consolidated_matrix_reports_paginated
      set_consolidated_matrix_filters
      base_query = build_consolidated_matrix_base_query
      pending_rows_list = build_consolidated_matrix_pending_rows(base_query)

      submitted_count = @selected_statuses.include?("submitted") ? base_query.count : 0
      pending_count = @selected_statuses.include?("pending") ? pending_rows_list.size : 0

      @total_matrix_count = submitted_count + pending_count
      page_num = [ (params[:page] || 1).to_i, 1 ].max
      items_per_page = 25

      @pagy = Pagy.new(count: @total_matrix_count, page: page_num, items: items_per_page)
      page_offset = @pagy.offset
      @paginated_matrix_rows = []

      if page_offset < submitted_count
        page_logs = base_query.includes(:assignment, participant: [ :user, :section ])
                              .order("assignment_response_logs.response_date DESC, assignment_response_logs.id DESC")
                              .offset(page_offset)
                              .limit(items_per_page)

        @paginated_matrix_rows.concat(load_matrix_answers_for_logs(page_logs))

        if @paginated_matrix_rows.size < items_per_page && pending_count > 0
          needed = items_per_page - @paginated_matrix_rows.size
          @paginated_matrix_rows.concat(pending_rows_list.slice(0, needed) || [])
        end
      else
        pending_offset = page_offset - submitted_count
        @paginated_matrix_rows.concat(pending_rows_list.slice(pending_offset, items_per_page) || [])
      end

      calculate_matrix_kpis(base_query, pending_rows_list)
      @matrix_rows = Array.new(@total_matrix_count)
    end

    def load_matrix_answers_for_logs(logs)
      return [] if logs.blank?

      p_ids = logs.map(&:participant_id).uniq
      a_ids = logs.map(&:assignment_id).uniq
      dates = logs.map { |l| l.response_date&.to_date }.compact.uniq
      all_response_ids = logs.flat_map { |l| Array(l.assignment_response_ids) }.map(&:to_i).reject(&:zero?).uniq

      responses = if all_response_ids.present?
                    AssignmentResponse.where(id: all_response_ids).includes(:question)
                  else
                    AssignmentResponse.where(participant_id: p_ids, assignment_id: a_ids)
                                      .where(response_date: dates.presence || nil)
                                      .includes(:question)
                  end

      responses_by_id = responses.index_by(&:id)
      answers_by_submission = Hash.new { |h, k| h[k] = {} }
      responses.each do |resp|
        sub_key = [ resp.participant_id, resp.assignment_id, resp.response_date&.to_date ]
        answer_text = if resp.answer.present?
                        resp.answer
                      elsif resp.selected_options.is_a?(Array)
                        resp.selected_options.reject(&:blank?).join(", ")
                      else
                        resp.selected_options.to_s
                      end
        answers_by_submission[sub_key][resp.question_id] = {
          answer: answer_text.presence || "-",
          question_type: resp.question&.question_type
        }
      end

      logs.map do |log|
        sub_date = log.response_date&.to_date
        sub_key = [ log.participant_id, log.assignment_id, sub_date ]
        log_answers = {}

        log_resp_ids = Array(log.assignment_response_ids).map(&:to_i).reject(&:zero?)
        if log_resp_ids.present?
          log_resp_ids.each do |resp_id|
            resp = responses_by_id[resp_id]
            next unless resp
            answer_text = if resp.answer.present?
                            resp.answer
                          elsif resp.selected_options.is_a?(Array)
                            resp.selected_options.reject(&:blank?).join(", ")
                          else
                            resp.selected_options.to_s
                          end
            log_answers[resp.question_id] = {
              answer: answer_text.presence || "-",
              question_type: resp.question&.question_type
            }
          end
        else
          log_answers = answers_by_submission[sub_key] || {}
        end

        {
          id: log.id,
          date: log.response_date,
          participant_id: log.participant_id,
          participant_name: log.participant&.full_name || "N/A",
          participant_email: log.participant&.email || "N/A",
          participant_type: log.participant&.participant_type,
          section_name: log.participant&.section&.name || "N/A",
          assignment_id: log.assignment_id,
          assignment_title: log.assignment&.title || "Assignment",
          status: "submitted",
          submitted_at: log.created_at,
          answers: log_answers
        }
      end
    end

    def calculate_matrix_kpis(base_query, pending_rows)
      submitted_participant_ids = base_query.distinct.pluck(:participant_id)
      pending_participant_ids = pending_rows.map { |r| r[:participant_id] }.compact.uniq
      all_filtered_participant_ids = (submitted_participant_ids + pending_participant_ids).uniq

      @filtered_participants_count = all_filtered_participant_ids.size

      if all_filtered_participant_ids.present?
        @participant_type_distribution = current_institute.participants
                                                          .where(id: all_filtered_participant_ids)
                                                          .group(:participant_type)
                                                          .count
      else
        @participant_type_distribution = {}
      end

      submitted_asg_ids = base_query.distinct.pluck(:assignment_id)
      pending_asg_ids = pending_rows.map { |r| r[:assignment_id] }.compact.uniq
      all_filtered_asg_ids = (submitted_asg_ids + pending_asg_ids).uniq
      @total_filtered_assignments = all_filtered_asg_ids.size

      @total_matrix_questions_count = @matrix_questions.size
      @total_submissions_count = base_query.count
      @total_pending_count = pending_rows.size

      @submitted_participants_count = submitted_participant_ids.size
      total_assigned_slots = @submitted_participants_count + @total_pending_count
      @overall_completion_rate = if total_assigned_slots > 0
                                   ((@submitted_participants_count.to_f / total_assigned_slots) * 100).round(1)
                                 else
                                   0.0
                                 end
    end

    def generate_consolidated_matrix_excel
      rows = @matrix_rows || []
      questions = @matrix_questions || []

      xml = String.new
      xml << %{<?xml version="1.0" encoding="UTF-8"?>\n}
      xml << %{<?mso-application progid="Excel.Sheet"?>\n}
      xml << %{<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n}
      xml << %{ xmlns:o="urn:schemas-microsoft-com:office:office"\n}
      xml << %{ xmlns:x="urn:schemas-microsoft-com:office:excel"\n}
      xml << %{ xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"\n}
      xml << %{ xmlns:html="http://www.w3.org/TR/REC-html40">\n}
      xml << %{ <Styles>\n}
      xml << %{  <Style ss:ID="Header">\n}
      xml << %{   <Font ss:Bold="1" ss:Color="#FFFFFF" ss:FontName="Segoe UI" ss:Size="11"/>\n}
      xml << %{   <Interior ss:Color="#1E293B" ss:Pattern="Solid"/>\n}
      xml << %{   <Alignment ss:Vertical="Center" ss:WrapText="1"/>\n}
      xml << %{  </Style>\n}
      xml << %{  <Style ss:ID="QuestionHeader">\n}
      xml << %{   <Font ss:Bold="1" ss:Color="#FFFFFF" ss:FontName="Segoe UI" ss:Size="10"/>\n}
      xml << %{   <Interior ss:Color="#312E81" ss:Pattern="Solid"/>\n}
      xml << %{   <Alignment ss:Vertical="Center" ss:WrapText="1"/>\n}
      xml << %{  </Style>\n}
      xml << %{  <Style ss:ID="RowSubmitted">\n}
      xml << %{   <Font ss:Color="#0F172A" ss:FontName="Segoe UI" ss:Size="10"/>\n}
      xml << %{   <Alignment ss:Vertical="Center" ss:WrapText="1"/>\n}
      xml << %{  </Style>\n}
      xml << %{  <Style ss:ID="BadgeSubmitted">\n}
      xml << %{   <Font ss:Bold="1" ss:Color="#15803D" ss:FontName="Segoe UI" ss:Size="10"/>\n}
      xml << %{   <Interior ss:Color="#DCFCE7" ss:Pattern="Solid"/>\n}
      xml << %{   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>\n}
      xml << %{  </Style>\n}
      xml << %{  <Style ss:ID="BadgePending">\n}
      xml << %{   <Font ss:Bold="1" ss:Color="#B45309" ss:FontName="Segoe UI" ss:Size="10"/>\n}
      xml << %{   <Interior ss:Color="#FEF3C7" ss:Pattern="Solid"/>\n}
      xml << %{   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>\n}
      xml << %{  </Style>\n}
      xml << %{  <Style ss:ID="CellEmpty">\n}
      xml << %{   <Font ss:Color="#94A3B8" ss:FontName="Segoe UI" ss:Size="10"/>\n}
      xml << %{   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>\n}
      xml << %{  </Style>\n}
      xml << %{ </Styles>\n}

      # WORKSHEET 1: Question Matrix
      xml << %{ <Worksheet ss:Name="Question Matrix">\n}
      xml << %{  <Table>\n}
      xml << %{   <Column ss:Width="40"/>\n}
      xml << %{   <Column ss:Width="90"/>\n}
      xml << %{   <Column ss:Width="160"/>\n}
      xml << %{   <Column ss:Width="90"/>\n}
      xml << %{   <Column ss:Width="180"/>\n}
      xml << %{   <Column ss:Width="110"/>\n}
      xml << %{   <Column ss:Width="170"/>\n}
      xml << %{   <Column ss:Width="90"/>\n}
      xml << %{   <Column ss:Width="110"/>\n}
      questions.each do
        xml << %{   <Column ss:Width="200"/>\n}
      end

      xml << %{   <Row ss:Height="28">\n}
      info_headers = [ "#", "Response Date", "Participant Name", "Participant Type", "Email", "Section", "Assignment Title", "Status", "Submitted At" ]
      info_headers.each do |h|
        xml << %{    <Cell ss:StyleID="Header"><Data ss:Type="String">#{CGI.escapeHTML(h)}</Data></Cell>\n}
      end
      questions.each_with_index do |q, q_idx|
        q_label = "Q#{q_idx + 1}: #{q[:title]} (#{q[:question_type].to_s.humanize})"
        xml << %{    <Cell ss:StyleID="QuestionHeader"><Data ss:Type="String">#{CGI.escapeHTML(q_label)}</Data></Cell>\n}
      end
      xml << %{   </Row>\n}

      rows.each_with_index do |row, idx|
        status_style = row[:status] == "submitted" ? "BadgeSubmitted" : "BadgePending"
        date_str = row[:date].present? ? row[:date].strftime("%Y-%m-%d") : "-"
        time_str = row[:submitted_at].present? ? row[:submitted_at].strftime("%I:%M %p") : "-"

        xml << %{   <Row ss:Height="22" ss:StyleID="RowSubmitted">\n}
        xml << %{    <Cell><Data ss:Type="Number">#{idx + 1}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(date_str)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:participant_name].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:participant_type].to_s.titleize)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:participant_email].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:section_name].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(row[:assignment_title].to_s)}</Data></Cell>\n}
        xml << %{    <Cell ss:StyleID="#{status_style}"><Data ss:Type="String">#{CGI.escapeHTML(row[:status].to_s.titleize)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(time_str)}</Data></Cell>\n}

        row_answers = row[:answers] || {}
        questions.each do |q|
          q_info = row_answers[q[:id]]
          if q_info.present?
            val = q_info[:answer].to_s
            xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(val)}</Data></Cell>\n}
          else
            dash = row[:status] == "submitted" ? "-" : "Pending"
            xml << %{    <Cell ss:StyleID="CellEmpty"><Data ss:Type="String">#{dash}</Data></Cell>\n}
          end
        end
        xml << %{   </Row>\n}
      end

      xml << %{  </Table>\n}
      xml << %{ </Worksheet>\n}

      # WORKSHEET 2: Question Summary & Stats
      xml << %{ <Worksheet ss:Name="Question Summary">\n}
      xml << %{  <Table>\n}
      xml << %{   <Column ss:Width="40"/>\n}
      xml << %{   <Column ss:Width="260"/>\n}
      xml << %{   <Column ss:Width="140"/>\n}
      xml << %{   <Column ss:Width="240"/>\n}
      xml << %{   <Column ss:Width="120"/>\n}
      xml << %{   <Row ss:Height="26" ss:StyleID="Header">\n}
      xml << %{    <Cell><Data ss:Type="String">#</Data></Cell>\n}
      xml << %{    <Cell><Data ss:Type="String">Question Title</Data></Cell>\n}
      xml << %{    <Cell><Data ss:Type="String">Question Type</Data></Cell>\n}
      xml << %{    <Cell><Data ss:Type="String">Assignments Covered</Data></Cell>\n}
      xml << %{    <Cell><Data ss:Type="String">Answers Provided</Data></Cell>\n}
      xml << %{   </Row>\n}

      questions.each_with_index do |q, q_idx|
        answered_cnt = rows.count do |r|
          ans = (r[:answers] || {})[q[:id]]
          ans && ans[:answer].present? && ans[:answer] != "-"
        end
        xml << %{   <Row ss:Height="20" ss:StyleID="RowSubmitted">\n}
        xml << %{    <Cell><Data ss:Type="Number">#{q_idx + 1}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(q[:title].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(q[:question_type].to_s.humanize)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="String">#{CGI.escapeHTML(q[:assignments_text].to_s)}</Data></Cell>\n}
        xml << %{    <Cell><Data ss:Type="Number">#{answered_cnt}</Data></Cell>\n}
        xml << %{   </Row>\n}
      end

      xml << %{  </Table>\n}
      xml << %{ </Worksheet>\n}
      xml << %{</Workbook>\n}

      xml
    end

    def generate_consolidated_matrix_csv
      require "csv"
      rows = @matrix_rows || []
      questions = @matrix_questions || []

      CSV.generate(headers: true) do |csv|
        headers = [ "#", "Response Date", "Participant Name", "Participant Type", "Email", "Section", "Assignment Title", "Status", "Submitted At" ]
        questions.each_with_index do |q, q_idx|
          headers << "Q#{q_idx + 1}: #{q[:title]}"
        end
        csv << headers

        rows.each_with_index do |row, index|
          row_answers = row[:answers] || {}
          row_vals = [
            index + 1,
            row[:date].present? ? row[:date].strftime("%Y-%m-%d") : "-",
            row[:participant_name],
            row[:participant_type].to_s.titleize,
            row[:participant_email],
            row[:section_name],
            row[:assignment_title],
            row[:status].to_s.titleize,
            row[:submitted_at].present? ? row[:submitted_at].strftime("%I:%M %p") : "-"
          ]

          questions.each do |q|
            q_info = row_answers[q[:id]]
            row_vals << (q_info ? q_info[:answer].to_s : (row[:status] == "submitted" ? "-" : "Pending"))
          end

          csv << row_vals
        end
      end
    end

    def render_assignment_report_pdf
      submission_status = params[:submission_status] || "submitted"
      report_title = submission_status == "submitted" ? "Submitted Assignments Report" : "Not Submitted Assignments Report"

      # Get filter information for the report header
      date_range_text = case @date_range
      when "today"
                          "Today (#{Date.current.strftime('%b %d, %Y')})"
      when "yesterday"
                          "Yesterday (#{Date.yesterday.strftime('%b %d, %Y')})"
      when "last_7_days"
                          "Last 7 Days"
      when "this_month"
                          "This Month (#{Date.current.strftime('%B %Y')})"
      when "custom"
                          "#{@start_date.strftime('%b %d, %Y')} to #{@end_date.strftime('%b %d, %Y')}"
      else
                          "All Dates"
      end

      section_text = if @section_id.present? && @section_id != "all"
                      section = current_institute.sections.find(@section_id)
                      "Section: #{section.name}"
      else
                      "All Sections"
      end

      assignment_text = if @assignment_id.present? && @assignment_id != "all"
                        assignment = current_institute.assignments.find(@assignment_id)
                        "Assignment: #{assignment.title}"
      else
                        "All Assignments"
      end

      # Generate PDF using Prawn directly
      pdf = generate_assignment_pdf(
        report_title: report_title,
        date_range: date_range_text,
        section: section_text,
        assignment: assignment_text,
        institute_name: current_institute.name,
        submission_status: submission_status
      )

      # Check if the user wants to download or preview
      disposition = params[:download] == "true" ? "attachment" : "inline"

      send_data pdf.render,
        filename: "assignment_report_#{Date.current.strftime('%Y%m%d')}.pdf",
        type: "application/pdf",
        disposition: disposition
    end

    def generate_assignment_pdf(options = {})
      require "prawn"
      require "prawn/table"

      pdf = Prawn::Document.new(
        page_size: "A4",
        margin: [ 30, 30, 30, 30 ],
        info: {
          Title: options[:report_title],
          Author: current_institute.name,
          Subject: "Assignment Report",
          Creator: "BeYa",
          CreationDate: Time.now
        }
      )

      # Add logo if present
      if current_institute.respond_to?(:logo) &&
         current_institute.logo.present? &&
         current_institute.logo.respond_to?(:attached?) &&
         current_institute.logo.attached?
        begin
          logo_path = ActiveStorage::Blob.service.path_for(current_institute.logo.key)
          pdf.image logo_path, position: :center, width: 120
        rescue => e
          # Skip logo if it can't be processed
          Rails.logger.warn "Failed to add logo to PDF: #{e.message}"
        end
      end

      # Report header
      pdf.font_size(18) { pdf.text options[:report_title], align: :center, style: :bold }
      pdf.move_down 10

      # Institute info
      pdf.font_size(14) { pdf.text options[:institute_name], align: :center, style: :bold }
      pdf.font_size(10) { pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}", align: :center, color: "666666" }
      pdf.move_down 20

      # Filter info
      filter_data = [
        [ "Date Range:", options[:date_range] ],
        [ "Section:", options[:section] ],
        [ "Assignment:", options[:assignment] ]
      ]

      pdf.table(filter_data, width: pdf.bounds.width * 0.7, position: :center) do
        cells.borders = []
        column(0).font_style = :bold
        column(0).width = 100
        column(0).align = :right
        column(1).align = :left
        cells.padding = [ 5, 10 ]
      end

      pdf.move_down 20

      # Report data
      if options[:submission_status] == "submitted"
        if @submitted_logs.any?
          # Table header
          header = [ "Date", "Participant", "Section" ]

          # Add assignment column if showing all assignments
          header << "Assignment" if @assignment_id.blank? || @assignment_id == "all"

          header << "Responses"

          # Table data
          data = []
          @submitted_logs.each do |log|
            row = [
              log.response_date.strftime("%b %d, %Y"),
              log.participant.full_name,
              log.participant.section.name
            ]

            row << log.assignment.title if @assignment_id.blank? || @assignment_id == "all"

            row << log.assignment_response_ids.size.to_s

            data << row
          end

          # Generate table
          pdf.table([ header ] + data, header: true, width: pdf.bounds.width) do
            cells.padding = [ 8, 10 ]

            row(0).font_style = :bold
            row(0).background_color = "EEEEEE"

            # Zebra striping
            rows(1..data.length).each_with_index do |row, i|
              row.background_color = "F5F5F5" if i.even?
            end
          end
        else
          pdf.text "No submitted assignments found for the selected criteria.", align: :center, style: :italic, color: "666666"
          pdf.stroke do
            pdf.rectangle [ 0, pdf.cursor ], pdf.bounds.width, 50
          end
        end
      else
        if @not_submitted_participants.any?
          # Table header
          header = [ "Participant", "Section", "Email" ]

          # Add assignment column if specific assignment is selected
          header << "Assignment" if @assignment_id.present? && @assignment_id != "all"

          # Table data
          data = []
          @not_submitted_participants.each do |participant|
            row = [
              participant.full_name,
              participant.section.name,
              participant.email
            ]

            row << @assignment_title if @assignment_id.present? && @assignment_id != "all"

            data << row
          end

          # Generate table
          pdf.table([ header ] + data, header: true, width: pdf.bounds.width) do
            cells.padding = [ 8, 10 ]

            row(0).font_style = :bold
            row(0).background_color = "EEEEEE"

            # Zebra striping
            rows(1..data.length).each_with_index do |row, i|
              row.background_color = "F5F5F5" if i.even?
            end
          end
        else
          pdf.text "No pending submissions found for the selected criteria.", align: :center, style: :italic, color: "666666"
          pdf.stroke do
            pdf.rectangle [ 0, pdf.cursor ], pdf.bounds.width, 50
          end
        end
      end

      # Footer
      pdf.number_pages "Page <page> of <total>",
                       at: [ pdf.bounds.right - 150, 0 ],
                       width: 150,
                       align: :right,
                       size: 9

      # Add footer note
      pdf.go_to_page(pdf.page_count)
      pdf.move_down 10
      pdf.horizontal_rule
      pdf.move_down 5
      pdf.text "This is a system generated report.", align: :center, size: 9, color: "666666"

      pdf
    end

    def render_individual_assignment_report_pdf
      pdf_data = generate_individual_assignment_pdf_with_ferrum
      disposition = params[:download] == "true" ? "attachment" : "inline"

      send_data pdf_data,
        filename: "individual_assignment_report_#{Date.current.strftime('%Y%m%d')}.pdf",
        type: "application/pdf",
        disposition: disposition
    end

    def generate_individual_assignment_pdf_with_ferrum
      participant = current_institute.participants.find_by(id: @participant_id) if @participant_id.present? && @participant_id != "all"
      @participant_title = participant&.full_name || "All Participants"

      html_content = render_to_string(
        template: "institute_admin/reports/individual_assignment_reports_pdf",
        formats: [ :html ],
        layout: false,
        locals: {
          current_institute: current_institute
        }
      )

      browser = self.class.ferrum_browser

      begin
        base64_html = Base64.strict_encode64(html_content)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(
          format: :A4,
          landscape: false,
          print_background: true
        )

        pdf_data = Base64.decode64(pdf_data) if pdf_data.present? && !pdf_data.start_with?("%PDF")
        pdf_data
      rescue StandardError => e
        Rails.logger.error("Ferrum PDF error: #{e.message}. Re-initializing Chrome instance...")
        self.class.reset_ferrum_browser!
        browser = self.class.ferrum_browser
        base64_html = Base64.strict_encode64(html_content)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(format: :A4, landscape: false, print_background: true)
        pdf_data = Base64.decode64(pdf_data) if pdf_data.present? && !pdf_data.start_with?("%PDF")
        pdf_data
      end
    end

    def generate_individual_assignment_pdf(options = {})
      require "prawn"
      require "prawn/table"

      pdf = Prawn::Document.new(
        page_size: "A4",
        margin: [ 30, 30, 30, 30 ],
        info: {
          Title: options[:report_title],
          Author: current_institute.name,
          Subject: "Individual Assignment Report",
          Creator: "BeYa",
          CreationDate: Time.now
        }
      )

      # Add logo if present
      if current_institute.respond_to?(:logo) &&
         current_institute.logo.present? &&
         current_institute.logo.respond_to?(:attached?) &&
         current_institute.logo.attached?
        begin
          logo_path = ActiveStorage::Blob.service.path_for(current_institute.logo.key)
          pdf.image logo_path, position: :center, width: 120
        rescue => e
          # Skip logo if it can't be processed
          Rails.logger.warn "Failed to add logo to PDF: #{e.message}"
        end
      end

      # Report header
      pdf.font_size(18) { pdf.text options[:report_title], align: :center, style: :bold }
      pdf.move_down 10

      # Institute info
      pdf.font_size(14) { pdf.text options[:institute_name], align: :center, style: :bold }
      pdf.font_size(10) { pdf.text "Generated on #{Date.current.strftime('%B %d, %Y')}", align: :center, color: "666666" }
      pdf.move_down 20

      # Filter info
      filter_data = [
        [ "Date Range:", options[:date_range] ],
        [ "Participant:", options[:participant] ],
        [ "Section:", options[:section] ],
        [ "Assignment:", options[:assignment] ]
      ]

      pdf.table(filter_data, width: pdf.bounds.width * 0.7, position: :center) do
        cells.borders = []
        column(0).font_style = :bold
        column(0).width = 100
        column(0).align = :right
        column(1).align = :left
        cells.padding = [ 5, 10 ]
      end

      pdf.move_down 20

      # Report data
      if @report_rows.present? && @report_rows.any?
        header = [ "Date", "Participant", "Section", "Assignment", "Status" ]

        data = @report_rows.map do |row|
          [
            row[:date].present? ? row[:date].strftime("%b %d, %Y") : "Pending",
            row[:participant_name].to_s,
            row[:section_name].to_s,
            row[:assignment_title].to_s,
            row[:status].to_s.titleize
          ]
        end

        pdf.table([ header ] + data, header: true, width: pdf.bounds.width) do
          cells.padding = [ 8, 10 ]
          row(0).font_style = :bold
          row(0).background_color = "EEEEEE"

          rows(1..data.length).each_with_index do |row, i|
            row.background_color = "F5F5F5" if i.even?
          end
        end
      else
        pdf.text "No assignment records found for the selected criteria.", align: :center, style: :italic, color: "666666"
      end

      # Footer
      pdf.number_pages "Page <page> of <total>",
                       at: [ pdf.bounds.right - 150, 0 ],
                       width: 150,
                       align: :right,
                       size: 9

      # Add footer note
      pdf.go_to_page(pdf.page_count)
      pdf.move_down 10
      pdf.horizontal_rule
      pdf.move_down 5
      pdf.text "This is a system generated report.", align: :center, size: 9, color: "666666"

      pdf
    end

    def render_section_feedback_report_pdf
      @submission_status = params[:submission_status] || "submitted"
      @report_title = @submission_status == "submitted" ? "Section Feedback Report" : "Not Submitted Section Feedback Report"

      # Get filter information for the report header
      @date_range_text = case @date_range
      when "today"
                          "Today (#{Date.current.strftime('%b %d, %Y')})"
      when "yesterday"
                          "Yesterday (#{Date.yesterday.strftime('%b %d, %Y')})"
      when "last_7_days"
                          "Last 7 Days"
      when "this_month"
                          "This Month (#{Date.current.strftime('%B %Y')})"
      when "custom"
                          "#{@start_date.strftime('%b %d, %Y')} to #{@end_date.strftime('%b %d, %Y')}"
      else
                          "All Dates"
      end

      @section_text = if @section_id.present? && @section_id != "all"
                      section = current_institute.sections.find(@section_id)
                      "Section: #{section.name}"
      else
                      "All Sections"
      end

      # Render the HTML template to a string
      html = render_to_string(
        template: "institute_admin/reports/section_feedback_report",
        formats: [ :html ],
        layout: "pdf"
      )

      # Generate PDF using Ferrum
      require "ferrum"
      require "base64"

      pdf_data = nil
      browser = self.class.ferrum_browser
      begin
        base64_html = Base64.strict_encode64(html)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(
          format: :A4,
          print_background: true,
          margin_top: 0.4,
          margin_bottom: 0.4,
          margin_left: 0.4,
          margin_right: 0.4
        )
      rescue StandardError => e
        Rails.logger.error("Ferrum PDF error: #{e.message}. Re-initializing Chrome instance...")
        self.class.reset_ferrum_browser!
        browser = self.class.ferrum_browser
        base64_html = Base64.strict_encode64(html)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(
          format: :A4,
          print_background: true,
          margin_top: 0.4,
          margin_bottom: 0.4,
          margin_left: 0.4,
          margin_right: 0.4
        )
      end

      # Decode Base64 if needed (Ferrum returns Base64 encoded string)
      if pdf_data.present? && !pdf_data.start_with?("%PDF")
        require "base64"
        pdf_data = Base64.decode64(pdf_data)
      end

      # Check if the user wants to download or preview
      disposition = params[:download] == "true" ? "attachment" : "inline"

      send_data pdf_data,
        filename: "section_feedback_report_#{Date.current.strftime('%Y%m%d')}.pdf",
        type: "application/pdf",
        disposition: disposition
    end



    def render_individual_feedback_report_pdf
      @submission_status = params[:submission_status] || "submitted"
      @report_title = @submission_status == "submitted" ? "Individual Feedback Report" : "Not Submitted Individual Feedback Report"

      participant = current_institute.participants.find(@participant_id)
      @participant_text = participant.full_name
      @section_text = participant.section.name

      # Get filter information for the report header
      @date_range_text = case @date_range
      when "today"
                          "Today (#{Date.current.strftime('%b %d, %Y')})"
      when "yesterday"
                          "Yesterday (#{Date.yesterday.strftime('%b %d, %Y')})"
      when "last_7_days"
                          "Last 7 Days"
      when "this_month"
                          "This Month (#{Date.current.strftime('%B %Y')})"
      when "custom"
                          "#{@start_date.strftime('%b %d, %Y')} to #{@end_date.strftime('%b %d, %Y')}"
      else
                          "All Dates"
      end

      @assignment_text = if @training_program_id.present? && @training_program_id != "all"
                        training_program = current_institute.training_programs.find(@training_program_id)
                        "Training Program: #{training_program.title}"
      else
                        "All Training Programs"
      end

      # Render the HTML template to a string
      html = render_to_string(
        template: "institute_admin/reports/individual_feedback_report",
        formats: [ :html ],
        layout: "pdf"
      )

      # Generate PDF using Ferrum
      require "ferrum"
      require "base64"

      pdf_data = nil
      browser = self.class.ferrum_browser
      begin
        base64_html = Base64.strict_encode64(html)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(
          format: :A4,
          print_background: true,
          margin_top: 0.4,
          margin_bottom: 0.4,
          margin_left: 0.4,
          margin_right: 0.4
        )
      rescue StandardError => e
        Rails.logger.error("Ferrum PDF error: #{e.message}. Re-initializing Chrome instance...")
        self.class.reset_ferrum_browser!
        browser = self.class.ferrum_browser
        base64_html = Base64.strict_encode64(html)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(
          format: :A4,
          print_background: true,
          margin_top: 0.4,
          margin_bottom: 0.4,
          margin_left: 0.4,
          margin_right: 0.4
        )
      end

      # Decode Base64 if needed (Ferrum returns Base64 encoded string)
      if pdf_data.present? && !pdf_data.start_with?("%PDF")
        pdf_data = Base64.decode64(pdf_data)
      end

      # Check if the user wants to download or preview
      disposition = params[:download] == "true" ? "attachment" : "inline"

      send_data pdf_data,
        filename: "individual_feedback_report_#{Date.current.strftime('%Y%m%d')}.pdf",
        type: "application/pdf",
        disposition: disposition
    end

    def generate_individual_certificate(certificate)
      require "prawn"
      require "prawn/table"
      require "gruff"
      require "tempfile"

      participant = certificate.participant
      assignment = certificate.assignment
      config = certificate.certificate_configuration

      # Get the date range for the assignment
      start_date = assignment.start_date.to_date
      end_date = assignment.end_date.to_date

      # Create interval periods based on certificate configuration
      intervals = []
      current_date = start_date

      while current_date <= end_date
        interval_end = [ current_date + config.duration_period.days - 1, end_date ].min
        intervals << [ current_date, interval_end ]
        current_date = interval_end + 1.day
      end

      # Get all responses for this assignment and participant
      responses = AssignmentResponse.where(
        participant: participant,
        assignment: assignment
      )

      # Group responses by date
      responses_by_date = responses.group_by { |r| r.response_date.to_date }

      # Filter for yes/no and number questions
      yes_no_questions = assignment.questions.where(question_type: "yes_or_no").select(:id, :title, :question_type)
      number_questions = assignment.questions.where(question_type: "number").select(:id, :title, :question_type)

      # Calculate data for the certificate
      table_data = []
      # Truncate question labels for x-axis to avoid overlap
      full_questions = (yes_no_questions + number_questions).map { |q| q.respond_to?(:title) ? q.title : "Question #{q.id}" }
      short_labels = full_questions.map.with_index { |q, i| q.length > 15 ? "Q#{i+1}: #{q[0, 12]}..." : "Q#{i+1}: #{q}" }
      # Simple labels for x-axis: just Q1, Q2, Q3, etc.
      simple_labels = full_questions.map.with_index { |q, i| "Q#{i+1}" }
      interval_names = intervals.each_with_index.map { |(_s, _e), idx| "#{(idx+1).ordinalize} #{config.duration_period} Days" }

      # Prepare table header with SI.No column
      header = [ "SI.No", "Question" ] + interval_names + [ "Total" ]
      table_data << header

      # Prepare interval data: interval_bars[interval][question_index] = value
      interval_bars = Array.new(intervals.size) { Array.new(full_questions.size, 0) }
      total_per_question = Array.new(full_questions.size, 0)
      days_submitted_per_interval = Array.new(intervals.size, 0)

      (yes_no_questions + number_questions).each_with_index do |question, q_idx|
        row = [ "Q#{q_idx + 1}", full_questions[q_idx] ]
        total = 0
        intervals.each_with_index do |(interval_start, interval_end), i_idx|
          value = 0
          (interval_start..interval_end).each do |date|
            date_responses = responses_by_date[date] || []
            question_responses = date_responses.select { |r| r.question_id == question.id }
            question_responses.each do |response|
              if question.question_type == "yes_or_no"
                value += 1 if response.answer.to_s.downcase == "yes"
              else
                value += response.answer.to_i if response.answer.present?
              end
            end
          end
          row << value
          interval_bars[i_idx][q_idx] = value
          total += value
        end
        row << total
        total_per_question[q_idx] = total
        table_data << row
      end

      # Calculate days submitted per interval
      # Count unique days where at least one response was submitted for any question
      intervals.each_with_index do |(interval_start, interval_end), i_idx|
        unique_days = 0
        (interval_start..interval_end).each do |date|
          date_responses = responses_by_date[date]
          # Check if there are any responses for this date for the questions we're tracking
          if date_responses.present?
            has_tracked_response = date_responses.any? do |r|
              (yes_no_questions + number_questions).any? { |q| q.id == r.question_id }
            end
            unique_days += 1 if has_tracked_response
          end
        end
        days_submitted_per_interval[i_idx] = unique_days
      end

      # Add "NUMBER OF DAYS SUBMITTED" row
      days_row = [ "", "NUMBER OF DAYS SUBMITTED" ]
      total_days_submitted = 0
      days_submitted_per_interval.each do |days|
        days_row << days
        total_days_submitted += days
      end
      days_row << total_days_submitted
      table_data << days_row

      # Calculate total number of days per interval
      # (considering assignment end date and current date)
      total_days_per_interval = []
      current_date = Date.current

      intervals.each do |(interval_start, interval_end)|
        # Find the actual end date (earliest of: interval_end, assignment end_date, or current_date)
        actual_end = [ interval_end, assignment.end_date.to_date, current_date ].min

        # Calculate number of days in this interval
        if actual_end >= interval_start
          num_days = (actual_end - interval_start).to_i + 1
        else
          num_days = 0
        end

        total_days_per_interval << num_days
      end

      # Add "TOTAL NUMBER OF DAYS" row
      total_days_row = [ "", "TOTAL NUMBER OF DAYS" ]
      total_all_days = 0
      total_days_per_interval.each do |days|
        total_days_row << days
        total_all_days += days
      end
      total_days_row << total_all_days
      table_data << total_days_row

      # Calculate participation percentage per interval
      # (Days Submitted / Total Days) * 100
      participation_percentages = []

      days_submitted_per_interval.each_with_index do |submitted, idx|
        total = total_days_per_interval[idx]
        if total > 0
          percentage = ((submitted.to_f / total) * 100).round(0)
        else
          percentage = 0
        end
        participation_percentages << percentage
      end

      # Add "PARTICIPATION PERCENTAGE" row
      percentage_row = [ "", "PARTICIPATION PERCENTAGE" ]
      total_percentage = total_all_days > 0 ? ((total_days_submitted.to_f / total_all_days) * 100).round(0) : 0
      participation_percentages.each do |percentage|
        percentage_row << "#{percentage}%"
      end
      percentage_row << "#{total_percentage}%"
      table_data << percentage_row

      # Calculate RANK based on participation percentages
      # Get all participants in the same section with certificates for this assignment and configuration
      all_section_certificates = IndividualCertificate.joins(:participant)
        .where(
          assignment: assignment,
          certificate_configuration: config,
          participants: { section_id: participant.section_id }
        )
        .includes(:participant)

      # Calculate percentages for all participants
      all_participant_data = []

      all_section_certificates.each do |cert|
        cert_participant = cert.participant
        cert_responses = AssignmentResponse.where(
          participant: cert_participant,
          assignment: assignment
        )

        cert_responses_by_date = cert_responses.group_by { |r| r.response_date.to_date }

        # Calculate days submitted and percentages for this participant
        cert_days_submitted = []
        cert_percentages = []

        intervals.each_with_index do |(interval_start, interval_end), i_idx|
          # Count days submitted
          unique_days = 0
          (interval_start..interval_end).each do |date|
            date_responses = cert_responses_by_date[date]
            if date_responses.present?
              has_tracked_response = date_responses.any? do |r|
                (yes_no_questions + number_questions).any? { |q| q.id == r.question_id }
              end
              unique_days += 1 if has_tracked_response
            end
          end
          cert_days_submitted << unique_days

          # Calculate percentage
          total_days = total_days_per_interval[i_idx]
          if total_days > 0
            percentage = ((unique_days.to_f / total_days) * 100).round(0)
          else
            percentage = 0
          end
          cert_percentages << percentage
        end

        # Calculate total percentage
        cert_total_days_submitted = cert_days_submitted.sum
        cert_total_percentage = total_all_days > 0 ? ((cert_total_days_submitted.to_f / total_all_days) * 100).round(0) : 0

        all_participant_data << {
          participant_id: cert_participant.id,
          percentages: cert_percentages,
          total_percentage: cert_total_percentage
        }
      end

      # Calculate ranks for each interval and total
      ranks_per_interval = Array.new(intervals.size) { [] }
      total_ranks = []

      # For each interval, sort by percentage descending and assign ranks
      intervals.each_with_index do |_, i_idx|
        sorted_percentages = all_participant_data.map { |pd| pd[:percentages][i_idx] }.sort.reverse.uniq

        all_participant_data.each do |pd|
          percentage = pd[:percentages][i_idx]
          rank = sorted_percentages.index(percentage) + 1
          ranks_per_interval[i_idx] << { participant_id: pd[:participant_id], rank: rank }
        end
      end

      # Calculate total rank
      sorted_total_percentages = all_participant_data.map { |pd| pd[:total_percentage] }.sort.reverse.uniq

      all_participant_data.each do |pd|
        total_perc = pd[:total_percentage]
        rank = sorted_total_percentages.index(total_perc) + 1
        total_ranks << { participant_id: pd[:participant_id], rank: rank }
      end

      # Get current participant's ranks
      current_participant_ranks = []
      intervals.each_with_index do |_, i_idx|
        rank_data = ranks_per_interval[i_idx].find { |r| r[:participant_id] == participant.id }
        current_participant_ranks << (rank_data ? rank_data[:rank] : "-")
      end

      total_rank_data = total_ranks.find { |r| r[:participant_id] == participant.id }
      current_total_rank = total_rank_data ? total_rank_data[:rank] : "-"

      # Add "RANK" row
      rank_row = [ "", "RANK" ]
      current_participant_ranks.each do |rank|
        rank_row << rank
      end
      rank_row << current_total_rank
      table_data << rank_row

      # Check eligibility based on total participation percentage
      # Compare with eligible_criteria from certificate configuration
      eligible_criteria = config.eligible_criteria || 0
      is_eligible = total_percentage >= eligible_criteria
      eligibility_status = is_eligible ? "Eligible" : "Not Eligible"

      # Add "ELIGIBLE FOR NEXT SESSION" row
      # This row will have merged cells for interval columns
      eligibility_row = [ "", "ELIGIBLE FOR NEXT SESSION" ]
      # Add a single merged cell for all intervals + total showing eligibility status
      eligibility_row << { content: eligibility_status, colspan: intervals.size + 1 }
      table_data << eligibility_row

      # Calculate available width and height for the chart
      chart_width = 535 # A4 width (595) - left/right margins (30 each)
      chart_height = 0 # Will be set later based on PDF layout

      # Create grouped bar graph: each interval is a series, x-axis is questions
      g = Gruff::Bar.new("#{chart_width}x350") # Initial height, will update below
      g.title = nil # Remove chart title

      g.theme = {
        colors: [
          "#4e73df", "#1cc88a", "#36b9cc", "#f6c23e", "#e74a3b", "#6a5acd", "#20b2aa", "#ff6347", "#ffb347", "#4682b4"
        ],
        marker_color: "#CCCCCC", # lighter axis/grid lines
        background_colors: [ "#ffffff", "#ffffff" ]
      }
      g.hide_legend = false
      g.legend_font_size = 14
      g.marker_font_size = 12
      g.title_font_size = 18
      g.bar_spacing = 0.5
      g.group_spacing = 8

      g.x_axis_label = "Questions"
      g.y_axis_label = "Count"
      g.minimum_value = 0
      g.maximum_value = [ interval_bars.flatten.max, 10 ].max

      interval_names.each_with_index do |iname, i_idx|
        g.data(iname, interval_bars[i_idx])
      end
      g.labels = short_labels.each_with_index.map { |lbl, idx| [ idx, lbl ] }.to_h
      g.hide_line_markers = false # Show axis lines only
      # Gruff shows axis lines by default; grid lines are hidden with hide_line_markers=false
      # Chart width set in Gruff::Bar.new("535x220")
      graph_file = Tempfile.new([ "certificate_graph", ".png" ])
      g.write(graph_file.path)

      # Generate the PDF in memory
      pdf_content = Prawn::Document.new(page_size: "A4", margin: [ 40, 30, 30, 30 ]) do |pdf|
        # Draw a subtle border on all pages
        pdf.repeat(:all) do
          pdf.stroke_color "888888"
          pdf.line_width = 1.2
          pdf.stroke_rectangle [ pdf.bounds.left, pdf.bounds.top ], pdf.bounds.width, pdf.bounds.height
        end
        # Set up fonts
        roboto_font_available = true
        font_paths = {
          normal: Rails.root.join("app/assets/fonts/Roboto-Regular.ttf"),
          bold: Rails.root.join("app/assets/fonts/Roboto-Bold.ttf"),
          italic: Rails.root.join("app/assets/fonts/Roboto-Italic.ttf")
        }

        # Check if font files exist
        font_paths.each do |style, path|
          unless File.exist?(path)
            Rails.logger.error "Font file not found: #{path}"
            roboto_font_available = false
          end
        end

        # Initialize fonts
        if roboto_font_available
          pdf.font_families.update(
            "Roboto" => {
              normal: font_paths[:normal],
              bold: font_paths[:bold],
              italic: font_paths[:italic]
            }
          )
          pdf.font "Roboto"
        else
          pdf.font "Helvetica"
        end


        # Colors (black/white/gray theme)
        primary_color = "000000"
        dark_color = "222222"
        border_color = "888888"

        # Header — logo immediately left of title, centred as a unit on the page
        institute = certificate.participant.user.institute
        title_text = config.name.present? ? config.name.upcase : "CERTIFICATE OF ACHIEVEMENT"
        logo_w = 48
        logo_h = 48

        if institute&.logo&.attached?
          begin
            inst_logo_path = ActiveStorage::Blob.service.path_for(institute.logo.key)
            pdf.move_down 20
            # Correct prawn-table syntax: image hash + plain string, styled via block
            header_data = [ [
              { image: inst_logo_path, fit: [ logo_w, logo_h ] },
              title_text
            ] ]
            pdf.table(header_data, position: :center,
                      cell_style: { borders: [], padding: [ 0, 8, 0, 0 ] }) do |t|
              t.column(0).width = logo_w + 4
              t.row(0).column(1).font_style = :bold
              t.row(0).column(1).size = 20
              t.row(0).column(1).valign = :center
              t.row(0).column(1).padding = [ 0, 0, 0, 8 ]
            end
          rescue => e
            Rails.logger.warn "Certificate: could not embed institute logo: #{e.message}"
            pdf.font_size 22
            pdf.fill_color primary_color
            pdf.text title_text, align: :center, style: :bold
          end
        else
          pdf.font_size 22
          pdf.fill_color primary_color
          pdf.text title_text, align: :center, style: :bold
        end
        pdf.move_down 6

        # Certificate details
        if config.details.present?
          pdf.font_size 10
          pdf.fill_color "666666"
          pdf.text config.details, align: :center, style: :italic
          pdf.move_down 20
        else
          pdf.move_down 15
        end

        # Participant name
        pdf.font_size 18
        pdf.fill_color dark_color
        pdf.text participant.user.full_name, align: :center, style: :bold
        pdf.move_down 5

        # Section name below participant
        pdf.font_size 11
        pdf.fill_color "555555"
        pdf.text "Section: #{participant.section.name}", align: :center
        pdf.move_down 12

        # Assignment completion details
        pdf.font_size 11
        pdf.fill_color dark_color
        pdf.text "For successfully completing:", align: :center
        pdf.move_down 4
        pdf.font_size 13
        pdf.text assignment.title, align: :center, style: :bold
        pdf.move_down 5
        pdf.font_size 9
        pdf.fill_color "666666"
        pdf.text "Date: #{assignment.start_date.strftime('%B %d, %Y')} - #{assignment.end_date.strftime('%B %d, %Y')}", align: :center
        pdf.move_down 30

        # Draw table first
        if table_data.size > 1
          pdf.font_size 9
          table_width = pdf.bounds.width - 10
          pdf.table table_data, width: table_width, position: :center do |t|
            t.header = true
            t.row(0).font_style = :bold
            t.row(0).background_color = dark_color
            t.row(0).text_color = "FFFFFF"
            t.row(0).min_font_size = 9
            t.row(0).align = :center # Center align all headers
            t.cells.borders = [ :top, :bottom, :left, :right ]
            t.cells.border_width = 0.4
            t.cells.border_color = border_color
            t.cells.padding = [ 6, 2 ] # Slightly smaller row height
            t.cells.align = :center # Center align all cells by default
            (1...table_data.length).each do |i|
              t.row(i).background_color = i % 2 == 1 ? "F0F0F0" : "FFFFFF"
            end
            # Special styling for summary rows at the bottom
            # "NUMBER OF DAYS SUBMITTED" row (fifth-to-last row)
            t.row(table_data.length - 5).font_style = :bold
            t.row(table_data.length - 5).background_color = "E8F4F8"
            # "TOTAL NUMBER OF DAYS" row (fourth-to-last row)
            t.row(table_data.length - 4).font_style = :bold
            t.row(table_data.length - 4).background_color = "FFF4E6"
            # "PARTICIPATION PERCENTAGE" row (third-to-last row)
            t.row(table_data.length - 3).font_style = :bold
            t.row(table_data.length - 3).background_color = "E8F8E8"
            # "RANK" row (second-to-last row)
            t.row(table_data.length - 2).font_style = :bold
            t.row(table_data.length - 2).background_color = "FFE8E8"
            # "ELIGIBLE FOR NEXT SESSION" row (last row)
            t.row(table_data.length - 1).font_style = :bold
            t.row(table_data.length - 1).background_color = "F0E8FF"
            # SI.No column styling
            t.column(0).font_style = :bold
            t.column(0).width = 40 # Compact width for SI.No
            # Question column styling
            t.column(1).font_style = :bold
            t.column(1).width = table_width * 0.35
            t.column(1).align = :left # Keep question text left-aligned
            # Total column styling
            t.column(t.column_length - 1).width = 70 # Wider to fit 'Eligible'/'Not Eligible'
          end
          pdf.move_down 20
        end

        # Calculate available height for the chart (space between here and the footer)
        available_height = pdf.bounds.bottom - pdf.cursor - 260 # 260 for footer and spacing
        chart_height = [ available_height, 250 ].max # Minimum height 250
        chart_width = pdf.bounds.width.to_i

        # Create high-resolution chart (2.5x resolution for sharp, high-quality output)
        # This will be scaled down in PDF for crisp rendering without font issues
        resolution_multiplier = 2.5
        high_res_width = (chart_width * resolution_multiplier).to_i
        high_res_height = (chart_height * resolution_multiplier).to_i

        g = Gruff::Bar.new("#{high_res_width}x#{high_res_height}")
        g.title = nil
        g.theme = {
          colors: [
            "#4e73df",  # Blue
            "#1cc88a",  # Green
            "#36b9cc",  # Cyan
            "#f6c23e",  # Yellow/Gold
            "#e74a3b",  # Red
            "#9b59b6",  # Purple (changed from similar blue)
            "#ff8c00",  # Dark Orange
            "#2ecc71",  # Emerald Green
            "#e91e63",  # Pink
            "#16a085"   # Teal
          ],
          marker_color: "#CCCCCC",
          background_colors: [ "#ffffff", "#ffffff" ]
        }
        g.hide_legend = false
        # Increase legend text clarity with larger font size
        g.legend_font_size = 12
        g.legend_box_size = 14
        g.marker_font_size = 14
        g.title_font_size = 18
        g.x_axis_label_font_size = 16 if g.respond_to?(:x_axis_label_font_size=)
        g.y_axis_label_font_size = 16 if g.respond_to?(:y_axis_label_font_size=)
        g.bar_spacing = 0.5
        g.group_spacing = 12
        # Remove axis labels for cleaner look
        g.x_axis_label = nil
        g.y_axis_label = nil
        g.minimum_value = 0
        g.maximum_value = [ interval_bars.flatten.max, 10 ].max
        interval_names.each_with_index do |iname, i_idx|
          g.data(iname, interval_bars[i_idx])
        end
        g.labels = simple_labels.each_with_index.map { |lbl, idx| [ idx, lbl ] }.to_h
        g.hide_line_markers = false
        graph_file = Tempfile.new([ "certificate_graph", ".png" ])
        g.write(graph_file.path)

        # Draw chart below table at target size (high-res image will be scaled down for sharp quality)
        if File.exist?(graph_file.path)
          pdf.image graph_file.path, fit: [ pdf.bounds.width, chart_height ], position: :center
          pdf.move_down 10
        end

        pdf.move_down 240
        # (Removed question key section)

        # Footer - positioned at rock bottom of page
        pdf.go_to_page(pdf.page_count)

        # Position footer at the absolute bottom (just above bottom margin)
        # Bottom margin is typically 36, so position at y=28 for rock bottom
        pdf.bounding_box([ 0, 28 ], width: pdf.bounds.width, height: 25) do
          # Add horizontal line separator
          pdf.stroke_color border_color
          pdf.horizontal_rule
          pdf.move_down 5

          # Footer text from configuration
          if config.certificate_left_footer.present? || config.certificate_right_footer.present?
            footer_table_data = []

            # Create a two-column layout for footer
            left_footer = config.certificate_left_footer.present? ? config.certificate_left_footer : ""
            right_footer = config.certificate_right_footer.present? ? config.certificate_right_footer : ""

            footer_table_data << [ left_footer, right_footer ]

            pdf.font_size 9
            pdf.fill_color "555555"
            pdf.table footer_table_data, width: pdf.bounds.width, cell_style: { borders: [], padding: [ 0, 5 ] } do |t|
              t.column(0).align = :left
              t.column(1).align = :right
            end
          end
        end
      end

      # Clean up temp file
      graph_file.close
      graph_file.unlink

      # Update certificate timestamp without storing file
      certificate.update(generated_at: Time.current)

      # Return the PDF content
      pdf_content.render
    rescue => e
      Rails.logger.error "Error generating certificate: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      certificate.errors.add(:base, "Certificate generation failed: #{e.message}")
      nil
    end

    # Close generate_individual_certificate method

    # `view_section_certificates` removed — section-based viewing consolidated into `view_certificates`
  end
end
