module InstituteAdmin
  class QuestionsController < InstituteAdmin::BaseController
    before_action :set_question, only: [ :show, :edit, :update, :destroy ]

    def index
      @institute = current_institute
      @all_questions = @institute.questions.where(participant_id: nil).includes(:options).order(position: :asc, created_at: :asc, id: :asc)
      @questions = @all_questions
      @question_types = Question.question_types.keys

      if params[:search].present?
        query = "%#{params[:search].downcase}%"
        @questions = @questions.where("LOWER(title) LIKE :q OR LOWER(display_name) LIKE :q", q: query)
      end

      if params[:question_type].present?
        @questions = @questions.where(question_type: params[:question_type])
      end

      if params[:status].present?
        is_active = params[:status] == "active"
        @questions = @questions.where(active: is_active)
      end

      # KPI Metrics (Calculated on filtered set)
      @total_questions_count = @questions.count
      @active_questions_count = @questions.where(active: true).count
      @types_count = @questions.pluck(:question_type).compact.uniq.count
      @required_questions_count = @questions.where(required: true).count

      respond_to do |format|
        format.html
        format.csv {
          send_data generate_questions_csv(@questions),
                    filename: "questions_bank_#{Date.current}.csv",
                    type: "text/csv"
        }
        format.pdf {
          pdf_data = generate_questions_pdf_with_ferrum
          send_data pdf_data,
                    filename: "questions_bank_#{Date.current}.pdf",
                    type: "application/pdf",
                    disposition: "inline"
        }
      end
    end

    def reorder
      if params[:question_ids].is_a?(Array)
        params[:question_ids].each_with_index do |id, index|
          current_institute.questions.where(id: id).update_all(position: index + 1)
        end
      end
      render json: { status: "success", message: "Question order updated successfully." }
    end

    def show
    end

    def new
      @question = current_institute.questions.build
    end

    def create
      begin
        # Get the parameters first
        question_parameters = sanitize_question_params(question_params)

        @question = current_institute.questions.build(question_parameters)

        # Final safety check before saving
        ensure_options_have_text(@question) if @question.requires_options?

        if @question.save
          @question.reload
          respond_to do |format|
            format.html { redirect_to institute_admin_question_path(@question), notice: "Question was successfully created." }
            format.json { render json: { status: "success", question: @question.as_json(include: :options) } }
          end
        else
          respond_to do |format|
            format.html { render :new, status: :unprocessable_entity }
            format.json { render json: { status: "error", errors: @question.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      rescue => e
        # Log the error
        Rails.logger.error("Error creating question: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        # Create a new question object for the form
        @question = current_institute.questions.build(question_params)

        # Add error message
        flash.now[:error] = "An error occurred while creating the question. Please try again."
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { status: "error", errors: [e.message] }, status: :unprocessable_entity }
        end
      end
    end

    def edit
    end

    def update
      begin
        if @question.institute_id.nil?
          # Cloning a master question for current_institute
          cloned = @question.dup
          cloned.institute = current_institute
          cloned.question_category = @question.question_category
          cloned.save!(validate: false)
          @question = cloned

          # Strip master option IDs so remaining options are cleanly created for this new question
          raw_options = question_params[:options_attributes]
          if raw_options.is_a?(Array)
            cleaned_attrs = raw_options.reject { |o| o[:_destroy] == "1" || o["_destroy"] == "1" }.map { |o| o.to_h.except("id", :id, "_destroy", :_destroy) }
            question_parameters = sanitize_question_params(question_params).merge(options_attributes: cleaned_attrs)
          elsif raw_options.is_a?(Hash) || raw_options.is_a?(ActionController::Parameters)
            cleaned_attrs = {}
            raw_options.each do |k, v|
              next if v[:_destroy] == "1" || v["_destroy"] == "1"
              cleaned_attrs[k] = v.to_h.except("id", :id, "_destroy", :_destroy)
            end
            question_parameters = sanitize_question_params(question_params).merge(options_attributes: cleaned_attrs)
          else
            question_parameters = sanitize_question_params(question_params)
          end
        else
          question_parameters = sanitize_question_params(question_params)

          if question_parameters[:options_attributes].present?
            # Collect option IDs that are kept active
            active_passed_ids = []
            if question_parameters[:options_attributes].is_a?(Array)
              question_parameters[:options_attributes].each do |opt|
                opt_id = (opt[:id] || opt["id"])&.to_s
                is_destroy = (opt[:_destroy] == "1" || opt["_destroy"] == "1" || opt[:_destroy] == true || opt["_destroy"] == true)
                active_passed_ids << opt_id if opt_id.present? && !is_destroy
              end
            elsif question_parameters[:options_attributes].is_a?(Hash) || question_parameters[:options_attributes].is_a?(ActionController::Parameters)
              question_parameters[:options_attributes].each do |_k, opt|
                opt_id = (opt[:id] || opt["id"])&.to_s
                is_destroy = (opt[:_destroy] == "1" || opt["_destroy"] == "1" || opt[:_destroy] == true || opt["_destroy"] == true)
                active_passed_ids << opt_id if opt_id.present? && !is_destroy
              end
            end

            # Mark any existing persisted options not in active_passed_ids for destruction
            @question.options.each do |opt|
              if opt.persisted? && !active_passed_ids.include?(opt.id.to_s)
                opt.mark_for_destruction
              end
            end
          elsif !@question.requires_options? && @question.options.any?
            @question.options.destroy_all
          end
        end

        # Final safety check before updating
        @question.assign_attributes(question_parameters)
        ensure_options_have_text(@question) if @question.requires_options?

        if @question.save
          @question.reload
          respond_to do |format|
            format.html { redirect_to institute_admin_question_path(@question), notice: "Question was successfully updated." }
            format.json { render json: { status: "success", question: @question.as_json(include: :options) } }
          end
        else
          respond_to do |format|
            format.html { render :edit, status: :unprocessable_entity }
            format.json { render json: { status: "error", errors: @question.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      rescue => e
        # Log the error
        Rails.logger.error("Error updating question: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))

        # Add error message
        flash.now[:error] = "An error occurred while updating the question. Please try again."
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: { status: "error", errors: [e.message] }, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @question = current_institute.questions.find(params[:id])

      if @question.destroy
        redirect_to institute_admin_questions_path, notice: "Question was successfully deleted."
      else
        error_msg = @question.errors.full_messages.to_sentence.presence || "Cannot delete Question because it is in use by assignments."
        redirect_to institute_admin_questions_path, alert: error_msg
      end
    end

    def duplicate
      begin
        original_question = current_institute.questions.includes(:options).find(params[:id])

        # Skip validation temporarily for the new question
        new_question = nil

        ActiveRecord::Base.transaction do
          # For question types that require options, we need to handle differently
          if original_question.requires_options?
            # First, create the question with validation skipped
            new_question = current_institute.questions.new(
              title: "Copy of #{original_question.title}",
              description: original_question.description,
              display_name: original_question.display_name ? "Copy of #{original_question.display_name}" : nil,
              question_type: original_question.question_type,
              required: original_question.required,
              active: original_question.active,
              max_rating: original_question.max_rating,
              duration_days: original_question.duration_days,
              from_day: original_question.from_day,
              to_day: original_question.to_day
            )

            # Temporarily disable validation
            new_question.validate_options_on_save = false if new_question.respond_to?(:validate_options_on_save=)

            # Save without validation first
            unless new_question.save(validate: false)
              error_message = "Failed to create question: #{new_question.errors.full_messages.join(', ')}"
              Rails.logger.error(error_message)
              raise ActiveRecord::Rollback, error_message
            end

            # Now duplicate all options
            if original_question.options.any?
              original_question.options.each do |original_option|
                new_option = new_question.options.new(
                  text: original_option.text,
                  value: original_option.value,
                  correct: original_option.correct
                )

                unless new_option.save
                  error_message = "Failed to save option: #{new_option.errors.full_messages.join(', ')}"
                  Rails.logger.error(error_message)
                  raise ActiveRecord::Rollback, error_message
                end
              end
            end

            # Now validate the question with its options
            unless new_question.valid?
              error_message = "Question validation failed after adding options: #{new_question.errors.full_messages.join(', ')}"
              Rails.logger.error(error_message)
              raise ActiveRecord::Rollback, error_message
            end
          else
            # For questions that don't require options, we can create normally
            new_question = current_institute.questions.new(
              title: "Copy of #{original_question.title}",
              description: original_question.description,
              display_name: original_question.display_name ? "Copy of #{original_question.display_name}" : nil,
              question_type: original_question.question_type,
              required: original_question.required,
              active: original_question.active,
              max_rating: original_question.max_rating,
              duration_days: original_question.duration_days,
              from_day: original_question.from_day,
              to_day: original_question.to_day
            )

            unless new_question.save
              error_message = "Failed to save question: #{new_question.errors.full_messages.join(', ')}"
              Rails.logger.error(error_message)
              raise ActiveRecord::Rollback, error_message
            end
          end
        end

        if new_question&.persisted?
          redirect_to institute_admin_questions_path, notice: "Question was successfully duplicated."
        else
          redirect_to institute_admin_questions_path, alert: "Failed to duplicate question. Please try again."
        end
      rescue => e
        Rails.logger.error("Error duplicating question: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        redirect_to institute_admin_questions_path, alert: "Failed to duplicate question: #{e.message}"
      end
    end

    private

    def set_question
      @question = Question.includes(:options).find(params[:id])
      if @question.institute_id.present? && @question.institute_id != current_institute.id
        raise ActiveRecord::RecordNotFound
      end
    end

    def question_params
      params.require(:question).permit(
        :title,
        :description,
        :display_name,
        :question_type,
        :required,
        :max_rating,
        :position,
        :duration_days,
        :from_day,
        :to_day,
        options_attributes: [ :id, :text, :correct, :_destroy ]
      )
    end

    # Sanitize parameters
    def sanitize_question_params(params)
      params
    end

    # Ensure all options have text check
    def ensure_options_have_text(question)
      # No-op: validation handled by Question model
    end

    def generate_questions_csv(questions)
      require "csv"
      CSV.generate(headers: true) do |csv|
        csv << [ "#", "Title", "Display Name", "Question Type", "Status", "Required", "Options Count", "Created Date" ]
        questions.each_with_index do |q, idx|
          csv << [
            idx + 1,
            q.title,
            q.display_name.presence || "Not Set",
            q.question_type.titleize,
            q.active? ? "Active" : "Inactive",
            q.required? ? "Yes" : "No",
            q.options.count,
            q.created_at.strftime("%Y-%m-%d %H:%M")
          ]
        end
      end
    end

    def generate_questions_pdf_with_ferrum
      html_content = render_to_string(
        template: "institute_admin/questions/pdf",
        formats: [ :html ],
        layout: false,
        locals: {
          questions: @questions,
          total_count: @total_questions_count,
          active_count: @active_questions_count,
          types_count: @types_count,
          required_count: @required_questions_count,
          institute: current_institute
        }
      )

      FerrumPdfGenerator.render(
        html_content,
        format: :A4,
        landscape: false,
        print_background: true
      )
    end
  end
end
