module ParticipantPortal
  class QuestionsController < ParticipantPortal::BaseController
    before_action :set_question, only: [ :show, :edit, :update, :destroy ]
    before_action :prevent_student_view_mutation, only: [ :new, :create, :edit, :update, :destroy ]

    def index
      @questions = current_participant.custom_questions.includes(:options).ordered

      if params[:search].present?
        query = "%#{params[:search].downcase}%"
        @questions = @questions.where("LOWER(title) LIKE :q OR LOWER(display_name) LIKE :q", q: query)
      end

      if params[:question_type].present?
        @questions = @questions.where(question_type: params[:question_type])
      end

      # KPI Metrics
      @total_questions_count = current_participant.custom_questions.count
      @active_questions_count = current_participant.custom_questions.where(active: true).count
      @types_count = current_participant.custom_questions.pluck(:question_type).compact.uniq.count
      @required_questions_count = current_participant.custom_questions.where(required: true).count

      respond_to do |format|
        format.html
        format.json { render json: @questions.as_json(include: :options) }
      end
    end

    def show
    end

    def new
      @question = current_participant.custom_questions.build(institute: current_institute, active: true)
      2.times { @question.options.build }
    end

    def create
      question_parameters = sanitize_question_params(question_params)
      @question = current_participant.custom_questions.build(question_parameters)
      @question.institute = current_institute

      ensure_options_have_text(@question) if @question.requires_options?

      if @question.save
        respond_to do |format|
          format.html { redirect_to participant_portal_questions_path, notice: "Question was successfully created.", status: :see_other }
          format.json { render json: { status: "success", question: @question.as_json(include: :options) } }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { status: "error", errors: @question.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error("Error creating participant question: #{e.message}\n#{e.backtrace.join("\n")}")
      @question ||= current_participant.custom_questions.build(question_params)
      flash.now[:alert] = "An error occurred while creating the question: #{e.message}"
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { status: "error", errors: [e.message] }, status: :unprocessable_entity }
      end
    end

    def edit
      if @question.requires_options? && @question.options.empty?
        2.times { @question.options.build }
      end
    end

    def update
      question_parameters = sanitize_question_params(question_params)

      if question_parameters[:options_attributes].present?
        # Handle options removal cleanly
        active_passed_ids = []
        opts = question_parameters[:options_attributes]
        opts_list = opts.is_a?(Array) ? opts : opts.values
        opts_list.each do |opt|
          opt_id = (opt[:id] || opt["id"])&.to_s
          is_destroy = (opt[:_destroy] == "1" || opt["_destroy"] == "1" || opt[:_destroy] == true)
          active_passed_ids << opt_id if opt_id.present? && !is_destroy
        end
        # Destroy options belonging to this question that were removed from the form
        @question.options.where.not(id: active_passed_ids).destroy_all if active_passed_ids.any?
      end

      if @question.update(question_parameters)
        ensure_options_have_text(@question) if @question.requires_options?
        redirect_to participant_portal_questions_path, notice: "Question was successfully updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @question.destroy
        redirect_to participant_portal_questions_path, notice: "Question was successfully deleted.", status: :see_other
      else
        redirect_to participant_portal_questions_path, alert: @question.errors.full_messages.to_sentence.presence || "Cannot delete question.", status: :see_other
      end
    end

    private

    def set_question
      @question = current_participant.custom_questions.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to participant_portal_questions_path, alert: "Question not found or you don't have permission to access it."
    end

    def prevent_student_view_mutation
      if viewing_as_student?
        redirect_to participant_portal_questions_path,
          alert: "You are in view-only mode. Questions cannot be modified while viewing a student's profile."
      end
    end

    def question_params
      params.require(:question).permit(
        :title,
        :display_name,
        :description,
        :question_type,
        :required,
        :max_rating,
        :from_day,
        :to_day,
        :active,
        options_attributes: [ :id, :value, :text, :correct, :_destroy ]
      )
    end

    def sanitize_question_params(params)
      cleaned = params.dup

      if cleaned[:options_attributes].present?
        raw_options = cleaned[:options_attributes]
        cleaned_options = {}

        if raw_options.is_a?(Array)
          raw_options.each_with_index do |opt, idx|
            cleaned_options[idx.to_s] = opt
          end
        elsif raw_options.is_a?(Hash) || raw_options.is_a?(ActionController::Parameters)
          cleaned_options = raw_options
        end

        # Keep options that have text or are marked for destruction
        cleaned_options = cleaned_options.select do |_key, opt|
          opt[:_destroy] == "1" || opt["_destroy"] == "1" || opt[:text].present? || opt["text"].present?
        end

        # Fill value with text if value is blank
        cleaned_options.each do |_key, opt|
          if (opt[:value].blank? && opt["value"].blank?) && (opt[:text].present? || opt["text"].present?)
            opt[:value] = opt[:text] || opt["text"]
          end
        end

        cleaned[:options_attributes] = cleaned_options
      end

      cleaned
    end

    def ensure_options_have_text(question)
      question.options.each do |option|
        if option.value.blank? && option.text.present?
          option.value = option.text
        elsif option.text.blank? && option.value.present?
          option.text = option.value
        end
      end
    end
  end
end
