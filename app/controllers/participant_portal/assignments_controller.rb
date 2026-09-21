module ParticipantPortal
  class AssignmentsController < ParticipantPortal::BaseController
    before_action :set_assignment, except: [ :index, :new, :create ]
    before_action :prevent_student_view_mutation, only: [ :take_assignment, :submit, :new, :create, :edit, :update, :destroy ]
    before_action :ensure_own_custom_assignment, only: [ :edit, :update, :destroy ]
    before_action :check_date_availability, only: [ :submit ]

    def index
      @selected_date = parse_date(params[:date])

      # Direct SQL approach for PostgreSQL compatibility
      # This avoids the DISTINCT issues by explicitly selecting all columns we need to order by
      base_sql = <<-SQL
        SELECT DISTINCT ON (assignments.id) assignments.*
        FROM assignments
        LEFT JOIN assignment_participants ON assignments.id = assignment_participants.assignment_id
        LEFT JOIN assignment_sections ON assignments.id = assignment_sections.assignment_id
        WHERE assignments.active = true
        AND (assignment_participants.participant_id = :participant_id OR assignment_sections.section_id = :section_id)
      SQL

      base_params = {
        participant_id: current_participant.id,
        section_id: current_participant.section_id
      }

      # Today's assignments
      today_sql = base_sql + " AND DATE(assignments.start_date) <= :today AND DATE(assignments.end_date) >= :today ORDER BY assignments.id, assignments.created_at DESC"
      @today_assignments = Assignment.find_by_sql([ today_sql, base_params.merge(today: Date.current) ])

      # IDs of today's assignments to exclude from upcoming
      today_ids = @today_assignments.map(&:id)

      # Upcoming assignments
      upcoming_sql = base_sql + " AND DATE(assignments.end_date) >= :today AND assignments.id NOT IN (:today_ids) ORDER BY assignments.id, assignments.start_date ASC"
      upcoming_params = base_params.merge(today: Date.current, today_ids: today_ids.empty? ? [ 0 ] : today_ids)
      @upcoming_assignments = Assignment.find_by_sql([ upcoming_sql, upcoming_params ])

      # Past assignments
      past_sql = base_sql + " AND DATE(assignments.end_date) < :today ORDER BY assignments.id, assignments.end_date DESC"
      @past_assignments = Assignment.find_by_sql([ past_sql, base_params.merge(today: Date.current) ])

      # For the date selection in the view
      date_sql = base_sql + " AND DATE(assignments.start_date) <= :selected_date AND DATE(assignments.end_date) >= :selected_date ORDER BY assignments.id, assignments.created_at DESC"
      date_assignments = Assignment.find_by_sql([ date_sql, base_params.merge(selected_date: @selected_date) ])

      # Also create a regular relation for all assignments
      @assignments = Assignment.select("assignments.*")
                               .active
                               .joins("LEFT JOIN assignment_participants ON assignments.id = assignment_participants.assignment_id")
                               .joins("LEFT JOIN assignment_sections ON assignments.id = assignment_sections.assignment_id")
                               .where("assignment_participants.participant_id = :participant_id OR assignment_sections.section_id = :section_id",
                                 participant_id: current_participant.id,
                                 section_id: current_participant.section_id)
                               .distinct

      respond_to do |format|
        format.html # Will render index.html.erb template
        format.turbo_stream {
          if params[:date].present?
            render turbo_stream: turbo_stream.update("assignment_content",
              partial: "participant_portal/dashboard/daily_assignments",
              locals: {
                assignments: date_assignments,
                selected_date: @selected_date
              }
            )
          else
            render :index, formats: [:html]
          end
        }
      end
    end

    def show
      @selected_date = parse_date(params[:date])
      @already_submitted = @assignment.answered_by_on_date?(current_participant, @selected_date)
      @existing_responses = current_participant.assignment_responses.where(
        assignment: @assignment,
        response_date: @selected_date
      ).index_by(&:question_id)
      @grouped_questions = @assignment.questions_grouped_by_bundle_for_date(@selected_date)

      respond_to do |format|
        format.html # renders show.html.erb
        format.turbo_stream {
          render turbo_stream: turbo_stream.update("main_content",
            template: "participant_portal/assignments/show"
          )
        }
      end
    end

    def take_assignment
      @selected_date = parse_date(params[:date])
      @already_submitted = @assignment.answered_by_on_date?(current_participant, @selected_date)
      @existing_responses = current_participant.assignment_responses.where(
        assignment: @assignment,
        response_date: @selected_date
      ).index_by(&:question_id)
      @questions = @assignment.all_questions_for_date(@selected_date)
      @grouped_questions = @assignment.questions_grouped_by_bundle_for_date(@selected_date)
    end

    def submit
      raw_responses = params[:responses]
      @responses = raw_responses.present? ? raw_responses.to_unsafe_h : {}

      # First check if already submitted
      if @assignment.answered_by_on_date?(current_participant, @selected_date)
        flash[:alert] = "You have already submitted this assignment for #{@selected_date.strftime('%B %d, %Y')}"
        redirect_to participant_portal_root_path
        return
      end

      validation_errors = []
      success = false

      begin
        ActiveRecord::Base.transaction do
          all_saved = true
          saved_response_ids = []

          @responses.each do |question_id, response_data|
            question = Question.find(question_id)
            response = current_participant.assignment_responses.find_or_initialize_by(
              assignment: @assignment,
              question_id: question_id,
              response_date: @selected_date
            )

            # Handle different question types
            case question.question_type
            when "checkboxes"
              response.selected_options = response_data[:selected_options].presence || []
              response.answer = response.selected_options.join(", ")
            when "multiple_choice", "dropdown", "rating"
              response.answer = response_data[:answer]
              response.selected_options = [ response_data[:answer] ].compact
            when "short_answer", "paragraph", "number", "date", "time"
              response.answer = response_data[:answer]
              response.selected_options = []
            else
              # Default handling for any other question types
              response.answer = response_data[:answer]
              response.selected_options = response_data[:selected_options].presence || []
            end

            response.submitted_at = Time.current

            if response.save
              saved_response_ids << response.id
            else
              Rails.logger.error("Failed to save response: #{response.errors.full_messages.join(', ')}")
              validation_errors << "#{question.title}: #{response.errors.full_messages.join(', ')}"
              all_saved = false
            end
          end

          if all_saved && validation_errors.empty?
            AssignmentResponseLog.log_responses(
              participant: current_participant,
              assignment: @assignment,
              response_ids: saved_response_ids,
              response_date: @selected_date
            )
            success = true
          else
            raise ActiveRecord::Rollback
          end
        end

        if success
          redirect_to participant_portal_root_path(date: @selected_date),
                      notice: "Assignment submitted successfully!"
        else
          flash.now[:alert] = "Please fix the following errors:<br>#{validation_errors.join('<br>')}".html_safe
          @questions = @assignment.all_questions_for_date(@selected_date)
          @grouped_questions = @assignment.questions_grouped_by_bundle_for_date(@selected_date)
          render :take_assignment, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique => e
        # Likely caused by a concurrent submission; handle gracefully and inform the user
        Rails.logger.warn("Unique constraint violation when saving assignment responses: #{e.message}")

        if @assignment.answered_by_on_date?(current_participant, @selected_date)
          flash[:alert] = "It looks like you've already submitted this assignment for #{@selected_date.strftime('%B %d, %Y')}."
          redirect_to participant_portal_root_path and return
        else
          flash.now[:alert] = "Some responses were already recorded by a concurrent submission. Please review and try again."
          @questions = @assignment.all_questions_for_date(@selected_date)
          @grouped_questions = @assignment.questions_grouped_by_bundle_for_date(@selected_date)
          render :take_assignment, status: :conflict and return
        end
      rescue => e
        Rails.logger.error("Error in submit action: #{e.message}")
        flash.now[:alert] = "Error submitting assignment. Please try again."
        @questions = @assignment.all_questions_for_date(@selected_date)
        @grouped_questions = @assignment.questions_grouped_by_bundle_for_date(@selected_date)
        render :take_assignment, status: :unprocessable_entity
      end
    end

    def new
      @assignment = current_institute.assignments.build(
        assignment_type: "individual",
        start_date: Date.current,
        end_date: Date.current + 30.days,
        active: true
      )
      load_form_questions
    end

    def create
      cleaned_params = assignment_params.to_h
      raw_qids = cleaned_params.delete("question_ids") || cleaned_params.delete(:question_ids) || []
      question_ids = raw_qids.reject(&:blank?).map(&:to_i).uniq
      question_ids = current_participant.custom_questions.where(id: question_ids).pluck(:id)

      @assignment = current_institute.assignments.new(cleaned_params)
      @assignment.participant = current_participant
      @assignment.assignment_type = "individual"

      if question_ids.empty?
        @assignment.errors.add(:base, "Please select at least one of your custom questions for this assignment.")
        load_form_questions
        render :new, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        if @assignment.save
          # Create recipient link for current participant
          @assignment.assignment_participants.create!(participant: current_participant)

          # Associate selected questions
          question_ids.each_with_index do |qid, idx|
            @assignment.assignment_questions.create!(
              question_id: qid,
              order_number: idx + 1
            )
          end

          redirect_to participant_portal_assignments_path, status: :see_other, notice: "Custom assignment created successfully!"
          return
        end
      end

      load_form_questions
      render :new, status: :unprocessable_entity
    rescue => e
      Rails.logger.error("Error creating custom assignment: #{e.message}\n#{e.backtrace.join("\n")}")
      flash.now[:alert] = "Failed to create assignment: #{e.message}"
      load_form_questions
      render :new, status: :unprocessable_entity
    end

    def edit
      load_form_questions
    end

    def update
      cleaned_params = assignment_params.to_h
      raw_qids = cleaned_params.delete("question_ids") || cleaned_params.delete(:question_ids) || []
      question_ids = raw_qids.reject(&:blank?).map(&:to_i).uniq
      question_ids = current_participant.custom_questions.where(id: question_ids).pluck(:id)

      if question_ids.empty?
        @assignment.errors.add(:base, "Please select at least one of your custom questions for this assignment.")
        load_form_questions
        render :edit, status: :unprocessable_entity
        return
      end

      ActiveRecord::Base.transaction do
        if @assignment.update(cleaned_params)
          # Rebuild questions association
          @assignment.assignment_questions.destroy_all
          question_ids.each_with_index do |qid, idx|
            @assignment.assignment_questions.create!(
              question_id: qid,
              order_number: idx + 1
            )
          end

          redirect_to participant_portal_assignments_path, status: :see_other, notice: "Custom assignment updated successfully!"
          return
        end
      end

      load_form_questions
      render :edit, status: :unprocessable_entity
    rescue => e
      Rails.logger.error("Error updating custom assignment: #{e.message}\n#{e.backtrace.join("\n")}")
      flash.now[:alert] = "Failed to update assignment: #{e.message}"
      load_form_questions
      render :edit, status: :unprocessable_entity
    end

    def destroy
      if @assignment.destroy
        respond_to do |format|
          format.html { redirect_to participant_portal_assignments_path, status: :see_other, notice: "Custom assignment deleted successfully." }
          format.turbo_stream { redirect_to participant_portal_assignments_path, status: :see_other, notice: "Custom assignment deleted successfully." }
        end
      else
        respond_to do |format|
          format.html { redirect_to participant_portal_assignments_path, status: :see_other, alert: @assignment.errors.full_messages.to_sentence.presence || "Cannot delete assignment." }
          format.turbo_stream { redirect_to participant_portal_assignments_path, status: :see_other, alert: @assignment.errors.full_messages.to_sentence.presence || "Cannot delete assignment." }
        end
      end
    end

    private

    def set_assignment
      @assignment = Assignment.find(params[:id])
      unless @assignment.available_for?(current_participant) || @assignment.participant_id == current_participant.id || @assignment.participants.include?(current_participant)
        redirect_to participant_portal_assignments_path, alert: "Assignment not found or access denied."
      end
    end

    def ensure_own_custom_assignment
      unless @assignment.participant_id == current_participant.id
        redirect_to participant_portal_assignments_path,
          alert: "You can only edit or delete assignments you created."
      end
    end

    def load_form_questions
      @my_questions = current_participant.custom_questions.includes(:options).ordered
      @selected_question_ids = @assignment.assignment_questions.order(:order_number).pluck(:question_id)
    end

    def assignment_params
      params.require(:assignment).permit(
        :title,
        :description,
        :start_date,
        :end_date,
        :active,
        question_ids: []
      )
    end

    def prevent_student_view_mutation
      if viewing_as_student?
        redirect_to participant_portal_assignments_path,
          alert: "You are in view-only mode. Assignments cannot be created or modified while viewing a student's profile."
      end
    end

    def check_date_availability
      @selected_date = parse_date(params[:date])

      if @assignment.answered_by_on_date?(current_participant, @selected_date)
        flash[:error] = "You have already submitted this assignment for #{@selected_date.strftime('%B %d, %Y')}"
        redirect_to participant_portal_root_path
        return
      end

      unless @assignment.available_for_date?(current_participant, @selected_date)
        flash[:error] = "This assignment is not available for the selected date"
        redirect_to participant_portal_root_path
      end
    end

    def parse_date(date_param)
      return Date.current unless date_param.present?
      Date.parse(date_param)
    rescue ArgumentError
      Date.current
    end
  end
end
