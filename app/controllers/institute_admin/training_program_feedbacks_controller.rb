module InstituteAdmin
  class TrainingProgramFeedbacksController < InstituteAdmin::BaseController
    before_action :set_training_program

    def index
      @all_feedbacks = @training_program.training_program_feedbacks
        .includes(participant: :user)
        .order(created_at: :desc)

      @feedbacks = @all_feedbacks

      if params[:rating].present?
        @feedbacks = @feedbacks.where(rating: params[:rating])
      end

      if params[:participant_type].present?
        @feedbacks = @feedbacks.joins(:participant).where(participants: { participant_type: params[:participant_type] })
      end

      if params[:search].present?
        query = "%#{params[:search].downcase}%"
        @feedbacks = @feedbacks.joins(participant: :user).where(
          "LOWER(users.first_name) LIKE :q OR LOWER(users.last_name) LIKE :q OR LOWER(training_program_feedbacks.content) LIKE :q",
          q: query
        )
      end

      if params[:date_range].present? && params[:date_range] != "all"
        case params[:date_range]
        when "today"
          @feedbacks = @feedbacks.where(created_at: Date.current.all_day)
        when "yesterday"
          @feedbacks = @feedbacks.where(created_at: Date.yesterday.all_day)
        when "last_7_days"
          @feedbacks = @feedbacks.where(created_at: 7.days.ago.beginning_of_day..Time.current)
        when "this_month"
          @feedbacks = @feedbacks.where(created_at: Time.current.beginning_of_month..Time.current)
        when "custom"
          if params[:start_date].present? && params[:end_date].present?
            s_date = Date.parse(params[:start_date]).beginning_of_day rescue nil
            e_date = Date.parse(params[:end_date]).end_of_day rescue nil
            @feedbacks = @feedbacks.where(created_at: s_date..e_date) if s_date && e_date
          end
        end
      elsif params[:start_date].present? || params[:end_date].present?
        s_date = params[:start_date].present? ? (Date.parse(params[:start_date]).beginning_of_day rescue nil) : 10.years.ago
        e_date = params[:end_date].present? ? (Date.parse(params[:end_date]).end_of_day rescue nil) : Time.current
        @feedbacks = @feedbacks.where(created_at: s_date..e_date) if s_date && e_date
      end

      # KPI Metrics (Calculated on filtered set)
      @total_feedbacks_count = @feedbacks.count
      @avg_rating = @total_feedbacks_count.positive? ? @feedbacks.average(:rating).to_f.round(1) : 0.0
      @five_star_count = @feedbacks.where(rating: 5).count
      @participant_types_count = @feedbacks.joins(:participant).pluck("participants.participant_type").compact.uniq.count

      # Rating Distribution Breakdown (5 stars to 1 star)
      # Base query respects participant_type, date_range, search (omits rating filter so all 5 bars are visible)
      dist_query = @training_program.training_program_feedbacks
      if params[:participant_type].present?
        dist_query = dist_query.joins(:participant).where(participants: { participant_type: params[:participant_type] })
      end
      if params[:search].present?
        query = "%#{params[:search].downcase}%"
        dist_query = dist_query.joins(participant: :user).where(
          "LOWER(users.first_name) LIKE :q OR LOWER(users.last_name) LIKE :q OR LOWER(training_program_feedbacks.content) LIKE :q",
          q: query
        )
      end
      if params[:date_range].present? && params[:date_range] != "all"
        case params[:date_range]
        when "today"
          dist_query = dist_query.where(created_at: Date.current.all_day)
        when "yesterday"
          dist_query = dist_query.where(created_at: Date.yesterday.all_day)
        when "last_7_days"
          dist_query = dist_query.where(created_at: 7.days.ago.beginning_of_day..Time.current)
        when "this_month"
          dist_query = dist_query.where(created_at: Time.current.beginning_of_month..Time.current)
        when "custom"
          if params[:start_date].present? && params[:end_date].present?
            s_date = Date.parse(params[:start_date]).beginning_of_day rescue nil
            e_date = Date.parse(params[:end_date]).end_of_day rescue nil
            dist_query = dist_query.where(created_at: s_date..e_date) if s_date && e_date
          end
        end
      elsif params[:start_date].present? || params[:end_date].present?
        s_date = params[:start_date].present? ? (Date.parse(params[:start_date]).beginning_of_day rescue nil) : 10.years.ago
        e_date = params[:end_date].present? ? (Date.parse(params[:end_date]).end_of_day rescue nil) : Time.current
        dist_query = dist_query.where(created_at: s_date..e_date) if s_date && e_date
      end

      dist_total = dist_query.count
      raw_rating_counts = dist_query.group(:rating).count
      @rating_distribution = [5, 4, 3, 2, 1].map do |stars|
        count = raw_rating_counts[stars] || raw_rating_counts[stars.to_i] || 0
        pct = dist_total.positive? ? ((count.to_f / dist_total) * 100).round(1) : 0.0
        {
          stars: stars,
          count: count,
          percentage: pct
        }
      end
      positive_count = (raw_rating_counts[5] || 0) + (raw_rating_counts[4] || 0)
      @positive_rating_pct = dist_total.positive? ? ((positive_count.to_f / dist_total) * 100).round : 0
      @program_avg_rating = dist_total.positive? ? dist_query.average(:rating).to_f.round(1) : 0.0
      @program_total_feedbacks = dist_total

      respond_to do |format|
        format.html
        format.csv {
          send_data generate_feedbacks_csv(@feedbacks),
                    filename: "feedbacks_program_#{@training_program.id}_#{Date.current}.csv",
                    type: "text/csv"
        }
        format.pdf {
          pdf_data = generate_feedbacks_pdf_with_ferrum
          send_data pdf_data,
                    filename: "feedbacks_program_#{@training_program.id}_#{Date.current}.pdf",
                    type: "application/pdf",
                    disposition: "inline"
        }
      end
    end

    private

    def generate_feedbacks_csv(feedbacks)
      require "csv"
      CSV.generate(headers: true) do |csv|
        csv << [ "#", "Participant Name", "Email", "Phone", "User Type", "Rating", "Feedback Comment", "Submitted Date" ]
        feedbacks.each_with_index do |feedback, idx|
          participant = feedback.participant
          user = participant&.user
          csv << [
            idx + 1,
            user&.full_name.presence || "Unknown User",
            user&.email,
            participant&.phone_number,
            (participant&.participant_type.presence || "student").titleize,
            "#{feedback.rating}/5",
            feedback.content,
            feedback.created_at.strftime("%Y-%m-%d %H:%M:%S")
          ]
        end
      end
    end

    def generate_feedbacks_pdf_with_ferrum
      require "ferrum"
      require "base64"

      html_content = render_to_string(
        template: "institute_admin/training_program_feedbacks/pdf",
        formats: [ :html ],
        layout: false,
        locals: {
          training_program: @training_program,
          feedbacks: @feedbacks,
          total_count: @total_feedbacks_count,
          avg_rating: @avg_rating,
          five_star_count: @five_star_count,
          participant_types_count: @participant_types_count
        }
      )

      browser = Ferrum::Browser.new(
        timeout: 30,
        process_timeout: 30,
        window_size: [ 1200, 1600 ],
        browser_options: {
          "no-sandbox": nil,
          "disable-gpu": nil,
          "disable-dev-shm-usage": nil
        }
      )

      begin
        base64_html = Base64.strict_encode64(html_content)
        data_uri = "data:text/html;base64,#{base64_html}"
        browser.go_to(data_uri)
        pdf_data = browser.pdf(
          format: :A4,
          landscape: false,
          print_background: true
        )

        if pdf_data.present? && !pdf_data.start_with?("%PDF")
          pdf_data = Base64.decode64(pdf_data)
        end

        pdf_data
      ensure
        browser.quit
      end
    end

    def set_training_program
      @training_program = current_institute.training_programs.find(params[:training_program_id])
    end
  end
end
