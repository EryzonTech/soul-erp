module InstituteAdmin
  class DashboardController < InstituteAdmin::BaseController
    def index
      # Total counts
      @total_participants = current_institute.participants.count
      @participant_type_distribution = current_institute.participants
                                                        .group(:participant_type)
                                                        .count
                                                        .transform_keys(&:to_s)

      # Today's assignment responses count & distribution
      @today_responses_count = AssignmentResponse.joins(:participant)
                .where(participants: { institute_id: current_institute.id }, response_date: Date.current)
                .count("DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)")
      @today_responses_by_type = fetch_today_responses_by_type(Date.current)

      @active_participants = current_institute.participants.active.count
      @total_trainers = current_institute.trainers.count
      @active_trainers = current_institute.active_trainers_count
      @total_sections = current_institute.sections.count
      @active_sections = current_institute.sections.active.count
      @total_questions = current_institute.questions.count
      @total_question_sets = current_institute.question_sets.count
      @total_assignments = current_institute.assignments.count
      @assignment_type_distribution = fetch_assignment_type_distribution

      @total_training_programs = current_institute.training_programs.count
      @training_programs_by_type = fetch_training_programs_by_type

      # Submissions Over Time & Backlog Trend (default: last 14 days)
      @submission_start_date = params[:submission_start_date].present? ? (Date.parse(params[:submission_start_date]) rescue (Date.current - 13.days)) : (Date.current - 13.days)
      @submission_end_date = params[:submission_end_date].present? ? (Date.parse(params[:submission_end_date]) rescue Date.current) : Date.current
      @submission_start_date, @submission_end_date = @submission_end_date, @submission_start_date if @submission_start_date > @submission_end_date

      sub_data = fetch_assignment_submission_data(@submission_start_date, @submission_end_date)
      @submissions_time_labels = sub_data[:labels]
      @submissions_time_data = sub_data[:total_data]
      @student_submissions_data = sub_data[:student_data]
      @guardian_submissions_data = sub_data[:guardian_data]
      @employee_submissions_data = sub_data[:employee_data]
      @backlog_labels = sub_data[:labels]
      @backlog_data = sub_data[:backlog_data]

      # Submissions by Assignment (Today / default: Date.current)
      @assignment_date = params[:assignment_date].present? ? (Date.parse(params[:assignment_date]) rescue Date.current) : Date.current
      asg_data = fetch_submissions_by_assignment(@assignment_date, @assignment_date)
      @assignment_labels = asg_data[:labels]
      @assignment_data = asg_data[:data]

      # Submissions by Section (Today / default: Date.current)
      @section_date = params[:section_date].present? ? (Date.parse(params[:section_date]) rescue Date.current) : Date.current
      sec_data = fetch_submissions_by_section(@section_date, @section_date)
      @submissions_section_labels = sec_data[:labels]
      @submissions_section_data = sec_data[:data]

      # Not-submitted by Assignment (Top 10)
      @not_submitted_date = params[:not_submitted_date].present? ? (Date.parse(params[:not_submitted_date]) rescue Date.current) : Date.current
      not_sub_data = fetch_not_submitted_by_assignment(@not_submitted_date)
      @not_submitted_assignment_labels = not_sub_data[:labels]
      @not_submitted_assignment_data = not_sub_data[:data]

      # Pending by Section (Top 10)
      @pending_section_date = params[:pending_section_date].present? ? (Date.parse(params[:pending_section_date]) rescue Date.current) : Date.current
      pend_data = fetch_pending_by_section(@pending_section_date)
      @pending_section_labels = pend_data[:labels]
      @pending_section_data = pend_data[:data]

      # Section-wise participant data
      section_data = current_institute.sections.active
        .select("sections.name, sections.capacity, COUNT(DISTINCT participants.id) as participant_count")
        .joins("LEFT JOIN participants ON participants.section_id = sections.id")
        .joins("LEFT JOIN users ON users.id = participants.user_id")
        .where(users: { active: true })
        .group("sections.id, sections.name, sections.capacity")
        .order("sections.name")

      @section_labels = section_data.map(&:name)
      @section_data = {
        participants: section_data.map(&:participant_count),
        capacity: section_data.map(&:capacity)
      }

      if @section_labels.empty?
        @section_labels = []
        @section_data = { participants: [], capacity: [] }
      end

      # Participant type data
      participant_types = current_institute.participants
        .joins(:user)
        .where(users: { active: true })
        .group(:participant_type)
        .count

      @type_labels = [ "Student", "Guardian", "Employee" ]
      @type_data = @type_labels.map { |type| participant_types[type.downcase] || 0 }

      # Training program statistics
      @active_programs_count = current_institute.training_programs.where(status: :ongoing).count
      @active_programs_percentage = calculate_percentage(@active_programs_count, @total_training_programs)

      # Feedback statistics
      calculate_feedback_statistics
      @feedback_by_type = fetch_feedback_by_type

      # Training program feedback data
      @program_feedback_data = get_program_feedback_data

      # Recent training programs
      @recent_programs = current_institute.training_programs
        .left_joins(:training_program_participants)
        .select("training_programs.*, COUNT(training_program_participants.id) AS participants_count")
        .group("training_programs.id")
        .order(created_at: :desc)
        .limit(5)
        .map do |program|
          program.define_singleton_method(:feedback_percentage) do
            total_participants = self[:participants_count].to_i
            return 0 if total_participants.zero?

            received_feedback = self.training_program_feedbacks_count.to_i
            ((received_feedback.to_f / total_participants) * 100).round
          end

          program.define_singleton_method(:participants_count) do
            self[:participants_count].to_i
          end

          program
        end
    end

    # AJAX endpoint for interactive chart filtering without full-page reload
    def chart_data
      case params[:chart]
      when "assignment_submission"
        start_date = params[:start_date].present? ? (Date.parse(params[:start_date]) rescue (Date.current - 13.days)) : (Date.current - 13.days)
        end_date = params[:end_date].present? ? (Date.parse(params[:end_date]) rescue Date.current) : Date.current
        start_date, end_date = end_date, start_date if start_date > end_date
        render json: { success: true, **fetch_assignment_submission_data(start_date, end_date) }

      when "submissions_by_assignment"
        start_date = params[:start_date].present? ? (Date.parse(params[:start_date]) rescue Date.current) : (params[:date].present? ? (Date.parse(params[:date]) rescue Date.current) : Date.current)
        end_date = params[:end_date].present? ? (Date.parse(params[:end_date]) rescue start_date) : start_date
        start_date, end_date = end_date, start_date if start_date > end_date
        render json: { success: true, **fetch_submissions_by_assignment(start_date, end_date) }

      when "submissions_by_section"
        start_date = params[:start_date].present? ? (Date.parse(params[:start_date]) rescue Date.current) : (params[:date].present? ? (Date.parse(params[:date]) rescue Date.current) : Date.current)
        end_date = params[:end_date].present? ? (Date.parse(params[:end_date]) rescue start_date) : start_date
        start_date, end_date = end_date, start_date if start_date > end_date
        render json: { success: true, **fetch_submissions_by_section(start_date, end_date) }

      when "not_submitted_assignment"
        date = params[:date].present? ? (Date.parse(params[:date]) rescue Date.current) : Date.current
        render json: { success: true, **fetch_not_submitted_by_assignment(date) }

      when "pending_section"
        date = params[:date].present? ? (Date.parse(params[:date]) rescue Date.current) : Date.current
        render json: { success: true, **fetch_pending_by_section(date) }

      when "backlog_trend"
        start_date = params[:start_date].present? ? (Date.parse(params[:start_date]) rescue (Date.current - 13.days)) : (Date.current - 13.days)
        end_date = params[:end_date].present? ? (Date.parse(params[:end_date]) rescue Date.current) : Date.current
        start_date, end_date = end_date, start_date if start_date > end_date
        date_range = (start_date..end_date).to_a
        render json: {
          success: true,
          labels: date_range.map { |d| d.strftime("%b %d") },
          raw_dates: date_range.map(&:to_s),
          data: fetch_backlog_data_for_range(start_date, end_date, date_range)
        }

      else
        render json: { success: false, error: "Invalid chart requested" }, status: :bad_request
      end
    rescue => e
      Rails.logger.error "DashboardController#chart_data error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      render json: { success: false, error: e.message }, status: :internal_server_error
    end

    private

    def fetch_assignment_submission_data(start_date, end_date)
      date_range = (start_date..end_date).to_a
      labels = date_range.map { |d| d.strftime("%b %d") }

      # Group submissions by date and participant_type
      subs_by_type = AssignmentResponse.joins(:participant)
        .where(participants: { institute_id: current_institute.id }, response_date: start_date..end_date)
        .group("assignment_responses.response_date", "participants.participant_type")
        .count("DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)")

      # Total submissions per date
      subs_total = AssignmentResponse.joins(:participant)
        .where(participants: { institute_id: current_institute.id }, response_date: start_date..end_date)
        .group("assignment_responses.response_date")
        .count("DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)")

      student_data = date_range.map { |d| subs_by_type[[ d, "student" ]] || 0 }
      guardian_data = date_range.map { |d| subs_by_type[[ d, "guardian" ]] || 0 }
      employee_data = date_range.map { |d| subs_by_type[[ d, "employee" ]] || 0 }
      total_data = date_range.map { |d| subs_total[d] || 0 }

      backlog_data = fetch_backlog_data_for_range(start_date, end_date, date_range)

      {
        labels: labels,
        raw_dates: date_range.map(&:to_s),
        student_data: student_data,
        guardian_data: guardian_data,
        employee_data: employee_data,
        total_data: total_data,
        backlog_data: backlog_data
      }
    rescue => e
      Rails.logger.error "Error preparing assignment submission data: #{e.message}"
      { labels: [], raw_dates: [], student_data: [], guardian_data: [], employee_data: [], total_data: [], backlog_data: [] }
    end

    def fetch_backlog_data_for_range(start_date, end_date, date_range)
      comp_counts = AssignmentResponseLog.where(institute_id: current_institute.id, response_date: start_date.beginning_of_day..end_date.end_of_day)
        .group("DATE(response_date)")
        .count("DISTINCT (assignment_id, participant_id)")
        .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k.to_date }

      exp_sql = ActiveRecord::Base.sanitize_sql_array([ <<-SQL, current_institute.id, end_date, start_date ])
        SELECT a.id, DATE(a.start_date) as s_date, DATE(a.end_date) as e_date, COUNT(DISTINCT p.id) as expected_count
        FROM assignments a
        LEFT JOIN assignment_participants ap ON ap.assignment_id = a.id
        LEFT JOIN assignment_sections asg ON asg.assignment_id = a.id
        LEFT JOIN participants p ON (ap.participant_id = p.id OR p.section_id = asg.section_id OR p.section_id = a.section_id)
        LEFT JOIN users u ON u.id = p.user_id
        WHERE a.active = true
          AND a.institute_id = ?
          AND u.active = true
          AND DATE(a.start_date) <= ? AND DATE(a.end_date) >= ?
        GROUP BY a.id, a.start_date, a.end_date
      SQL
      exp_assignments = ActiveRecord::Base.connection.exec_query(exp_sql).to_a

      date_range.map do |d|
        exp = exp_assignments.select { |a| a["s_date"].to_date <= d && a["e_date"].to_date >= d }.sum { |a| a["expected_count"].to_i }
        comp = comp_counts[d] || 0
        [ exp - comp, 0 ].max
      end
    rescue => e
      Rails.logger.error "Error preparing backlog trend data: #{e.message}"
      date_range.map { 0 }
    end

    def fetch_submissions_by_assignment(start_date, end_date)
      range = (start_date == end_date ? start_date : start_date..end_date)
      counts = AssignmentResponse.joins(:participant)
        .left_joins(:assignment)
        .where(participants: { institute_id: current_institute.id }, response_date: range)
        .group("assignments.id", Arel.sql("COALESCE(assignments.title, 'Deleted Assignment')"))
        .order(Arel.sql("COUNT(DISTINCT assignment_responses.participant_id) DESC"))
        .limit(10)
        .pluck(Arel.sql("COALESCE(assignments.title, 'Deleted Assignment')"), Arel.sql("COUNT(DISTINCT assignment_responses.participant_id)"))

      {
        labels: counts.map { |t, _| t || "Untitled" },
        data: counts.map { |_, c| c }
      }
    rescue => e
      Rails.logger.error "Error preparing submissions by assignment: #{e.message}"
      { labels: [], data: [] }
    end

    def fetch_submissions_by_section(start_date, end_date)
      range = (start_date == end_date ? start_date : start_date..end_date)
      counts = AssignmentResponse.joins(participant: :section)
        .where(participants: { institute_id: current_institute.id }, response_date: range)
        .group("sections.id", "sections.name")
        .order(Arel.sql("COUNT(DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id)) DESC"))
        .limit(10)
        .pluck("sections.name", Arel.sql("COUNT(DISTINCT (assignment_responses.assignment_id, assignment_responses.participant_id))"))

      {
        labels: counts.map { |t, _| t || "No Section" },
        data: counts.map { |_, c| c }
      }
    rescue => e
      Rails.logger.error "Error preparing submissions by section: #{e.message}"
      { labels: [], data: [] }
    end

    def fetch_not_submitted_by_assignment(date)
      assignments_sql = ActiveRecord::Base.sanitize_sql_array([ <<-SQL, date, current_institute.id, current_institute.id, date, date, current_institute.id ])
        SELECT a.id, a.title,
          COUNT(DISTINCT p.id) AS expected_count,
          COALESCE(cc.completed_count, 0) AS completed_count,
          (COUNT(DISTINCT p.id) - COALESCE(cc.completed_count, 0)) AS pending_count
        FROM assignments a
        LEFT JOIN assignment_participants ap ON ap.assignment_id = a.id
        LEFT JOIN assignment_sections asg ON asg.assignment_id = a.id
        LEFT JOIN participants p ON (ap.participant_id = p.id OR p.section_id = asg.section_id OR p.section_id = a.section_id)
        LEFT JOIN users u ON u.id = p.user_id AND u.active = true
        LEFT JOIN (
          SELECT assignment_id, COUNT(DISTINCT participant_id) AS completed_count
          FROM assignment_response_logs
          WHERE DATE(response_date) = ? AND institute_id = ?
          GROUP BY assignment_id
        ) cc ON cc.assignment_id = a.id
        WHERE a.active = true
          AND a.institute_id = ?
          AND DATE(a.start_date) <= ? AND DATE(a.end_date) >= ?
          AND p.institute_id = ?
        GROUP BY a.id, a.title, cc.completed_count
        HAVING (COUNT(DISTINCT p.id) - COALESCE(cc.completed_count, 0)) > 0
        ORDER BY pending_count DESC
        LIMIT 10
      SQL
      rows = ActiveRecord::Base.connection.exec_query(assignments_sql).to_a
      {
        labels: rows.map { |r| r["title"] || "Untitled" },
        data: rows.map { |r| r["pending_count"].to_i },
        expected: rows.map { |r| r["expected_count"].to_i },
        completed: rows.map { |r| r["completed_count"].to_i }
      }
    rescue => e
      Rails.logger.error "Error preparing not-submitted-by-assignment data: #{e.message}"
      { labels: [], data: [], expected: [], completed: [] }
    end

    def fetch_pending_by_section(date)
      sections_sql = ActiveRecord::Base.sanitize_sql_array([ <<-SQL, current_institute.id, date, date, date, current_institute.id, current_institute.id ])
        SELECT s.id, s.name,
          COUNT(DISTINCT (a.id, p.id)) AS expected_count,
          COUNT(DISTINCT CASE WHEN arl.id IS NOT NULL THEN (arl.assignment_id::text || '-' || arl.participant_id::text) END) AS completed_count,
          (COUNT(DISTINCT (a.id, p.id)) - COUNT(DISTINCT CASE WHEN arl.id IS NOT NULL THEN (arl.assignment_id::text || '-' || arl.participant_id::text) END)) AS pending_count
        FROM sections s
        JOIN participants p ON p.section_id = s.id AND p.institute_id = ?
        JOIN users u ON u.id = p.user_id AND u.active = true
        LEFT JOIN assignment_sections asg ON asg.section_id = s.id
        JOIN assignments a ON (a.id = asg.assignment_id OR a.section_id = s.id)
          AND a.active = true
          AND DATE(a.start_date) <= ? AND DATE(a.end_date) >= ?
        LEFT JOIN assignment_response_logs arl ON arl.assignment_id = a.id
          AND arl.participant_id = p.id
          AND DATE(arl.response_date) = ?
          AND arl.institute_id = ?
        WHERE s.institute_id = ?
        GROUP BY s.id, s.name
        HAVING (COUNT(DISTINCT (a.id, p.id)) - COUNT(DISTINCT CASE WHEN arl.id IS NOT NULL THEN (arl.assignment_id::text || '-' || arl.participant_id::text) END)) > 0
        ORDER BY pending_count DESC
        LIMIT 10
      SQL
      sec_rows = ActiveRecord::Base.connection.exec_query(sections_sql).to_a
      {
        labels: sec_rows.map { |r| r["name"] || "No Section" },
        data: sec_rows.map { |r| r["pending_count"].to_i }
      }
    rescue => e
      Rails.logger.error "Error preparing pending-by-section data: #{e.message}"
      { labels: [], data: [] }
    end

    def fetch_assignment_type_distribution
      sql = ActiveRecord::Base.sanitize_sql_array([ <<-SQL, current_institute.id ])
        SELECT p.participant_type, COUNT(DISTINCT a.id) as assignment_count
        FROM assignments a
        LEFT JOIN assignment_participants ap ON ap.assignment_id = a.id
        LEFT JOIN assignment_sections asg ON asg.assignment_id = a.id
        LEFT JOIN participants p ON (ap.participant_id = p.id OR p.section_id = asg.section_id OR p.section_id = a.section_id)
        WHERE a.institute_id = ?
        GROUP BY p.participant_type
      SQL
      ActiveRecord::Base.connection.exec_query(sql).to_h { |r| [ r["participant_type"].to_s, r["assignment_count"].to_i ] }
    rescue => e
      Rails.logger.error "Error preparing assignment type distribution: #{e.message}"
      {}
    end

    def fetch_today_responses_by_type(date = Date.current)
      sql = ActiveRecord::Base.sanitize_sql_array([ <<-SQL, current_institute.id, date ])
        SELECT p.participant_type, COUNT(DISTINCT (ar.assignment_id, ar.participant_id)) as response_count
        FROM assignment_responses ar
        JOIN participants p ON p.id = ar.participant_id
        WHERE p.institute_id = ? AND ar.response_date = ?
        GROUP BY p.participant_type
      SQL
      ActiveRecord::Base.connection.exec_query(sql).to_h { |r| [ r["participant_type"].to_s, r["response_count"].to_i ] }
    rescue => e
      Rails.logger.error "Error preparing today responses by type: #{e.message}"
      {}
    end

    def fetch_training_programs_by_type
      sql = ActiveRecord::Base.sanitize_sql_array([ <<-SQL, current_institute.id ])
        SELECT p.participant_type, COUNT(DISTINCT tp.id) as programs_count
        FROM training_programs tp
        LEFT JOIN training_program_participants tpp ON tpp.training_program_id = tp.id
        LEFT JOIN training_program_sections tps ON tps.training_program_id = tp.id
        LEFT JOIN participants p ON (tpp.participant_id = p.id OR p.section_id = tps.section_id OR tp.participant_id = p.id OR p.section_id = tp.section_id)
        WHERE tp.institute_id = ?
        GROUP BY p.participant_type
      SQL
      ActiveRecord::Base.connection.exec_query(sql).to_h { |r| [ r["participant_type"].to_s, r["programs_count"].to_i ] }
    rescue => e
      Rails.logger.error "Error preparing training programs by type: #{e.message}"
      {}
    end

    def fetch_feedback_by_type
      sql = ActiveRecord::Base.sanitize_sql_array([ <<-SQL, current_institute.id ])
        SELECT p.participant_type, COUNT(tpf.id) as feedback_count
        FROM training_program_feedbacks tpf
        JOIN training_programs tp ON tp.id = tpf.training_program_id
        JOIN participants p ON p.id = tpf.participant_id
        WHERE tp.institute_id = ?
        GROUP BY p.participant_type
      SQL
      ActiveRecord::Base.connection.exec_query(sql).to_h { |r| [ r["participant_type"].to_s, r["feedback_count"].to_i ] }
    rescue => e
      Rails.logger.error "Error preparing feedback by type: #{e.message}"
      {}
    end

    def calculate_feedback_statistics
      begin
        @total_feedback_received = TrainingProgramFeedback.joins(:training_program)
                                    .where(training_programs: { institute_id: current_institute.id })
                                    .count

        total_possible_feedback = TrainingProgramParticipant
          .joins(:training_program)
          .where(training_programs: { institute_id: current_institute.id })
          .count

        @total_feedback_pending = total_possible_feedback - @total_feedback_received
        @feedback_received_percentage = calculate_percentage(@total_feedback_received, total_possible_feedback)
        @feedback_pending_percentage = calculate_percentage(@total_feedback_pending, total_possible_feedback)
      rescue => e
        Rails.logger.error "Error calculating feedback statistics: #{e.message}"
        @total_feedback_received = 0
        @total_feedback_pending = 0
        @feedback_received_percentage = 0
        @feedback_pending_percentage = 0
      end
    end

    def get_program_feedback_data
      begin
        programs = current_institute.training_programs
                    .left_joins(:training_program_participants)
                    .select("training_programs.*, COUNT(training_program_participants.id) AS participants_count")
                    .group("training_programs.id")
                    .limit(10)

        result = programs.map do |program|
          total_participants = program[:participants_count].to_i
          received_feedback = program.training_program_feedbacks_count.to_i
          pending_feedback = [ total_participants - received_feedback, 0 ].max

          {
            name: program.title || "Unnamed Program",
            received: received_feedback,
            pending: pending_feedback,
            total: total_participants
          }
        end

        return [] if result.all? { |r| r[:received] == 0 && r[:pending] == 0 }

        result
      rescue => e
        Rails.logger.error "Error getting program feedback data: #{e.message}"
        []
      end
    end

    def calculate_percentage(part, total)
      return 0 if total.nil? || total.zero?
      ((part.to_f / total) * 100).round
    end
  end
end
