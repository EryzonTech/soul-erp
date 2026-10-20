module InstituteAdmin
  class AssignmentsController < InstituteAdmin::BaseController
    before_action :set_assignment, only: [ :show, :edit, :update, :destroy ]

    def index
      scope = current_institute.assignments.includes(:question_category)

      if params[:search].present?
        query = "%#{params[:search].strip}%"
        scope = scope.where("assignments.title ILIKE ? OR assignments.description ILIKE ?", query, query)
      end

      if params[:assignment_type].present?
        scope = scope.where(assignment_type: params[:assignment_type])
      end

      if params[:question_category_id].present?
        scope = scope.where(question_category_id: params[:question_category_id])
      end

      @total_assignments_count = current_institute.assignments.count
      @active_assignments_count = current_institute.assignments.where(active: true).count
      @assignments = scope.order(created_at: :desc)
      assignment_ids = @assignments.map(&:id)

      @sections_count_by_assignment_id = AssignmentSection.where(assignment_id: assignment_ids)
                                                           .group(:assignment_id)
                                                           .count
      @participants_count_by_assignment_id = AssignmentParticipant.where(assignment_id: assignment_ids)
                                                                 .group(:assignment_id)
                                                                 .count
      @questions_count_by_assignment_id = AssignmentQuestion.where(assignment_id: assignment_ids)
                                                             .group(:assignment_id)
                                                             .count
      @question_sets_count_by_assignment_id = AssignmentQuestionSet.where(assignment_id: assignment_ids)
                                                                   .group(:assignment_id)
                                                                   .count

      @total_participants_assigned_count = @participants_count_by_assignment_id.values.sum
      @total_questions_assigned_count = @questions_count_by_assignment_id.values.sum

      @categories_for_filter = QuestionCategory.where(id: current_institute.assignments.select(:question_category_id).where.not(question_category_id: nil).distinct).order(:name)
      @available_question_banks = QuestionBank.where(active: true).includes(:question_categories).order(:name)
    end

    def import_setup
      bank_id = params[:question_bank_id]
      selected_category_ids = Array(params[:category_ids]).reject(&:blank?)

      @question_bank = QuestionBank.find_by(id: bank_id)

      if @question_bank.nil?
        redirect_to new_institute_admin_assignment_path(mode: 'import_select'), alert: "Selected Question Bank not found."
        return
      end

      if selected_category_ids.empty?
        redirect_to new_institute_admin_assignment_path(mode: 'import_select', question_bank_id: bank_id), alert: "Please select at least one category to proceed with import setup."
        return
      end

      categories_scope = @question_bank.question_categories.where(active: true).where(id: selected_category_ids)

      @categories = categories_scope.includes(
        :questions,
        question_bundles: { question_bundle_items: { question: :options } }
      )

      if @categories.empty?
        redirect_to new_institute_admin_assignment_path(mode: 'import_select', question_bank_id: bank_id), alert: "No active categories selected for import."
        return
      end

      @custom_questions = current_institute.questions.includes(:options).order(position: :asc, created_at: :asc, id: :asc)
      @sections = current_institute.sections.active.joins(:participants).distinct.order(:name)
      @participants = current_institute.participants.active.includes(:user).ordered_by_name
    end

    def finalize_import
      assignments_data = params[:assignments]

      if assignments_data.blank?
        redirect_to institute_admin_assignments_path, alert: "No assignment configuration received."
        return
      end

      created_assignments = []

      ActiveRecord::Base.transaction do
        assignments_data.each do |category_id, data|
          category = QuestionCategory.find_by(id: category_id)
          next unless category

          # Clone master category as an Institution-wise separate entity
          inst_category = current_institute.question_categories.create!(
            name: category.name,
            description: category.description,
            duration_days: (category.duration_days.to_i > 0) ? category.duration_days.to_i : 30,
            active: true,
            question_bank_id: nil
          )

          start_date = data[:start_date].present? ? Date.parse(data[:start_date]) : Date.current
          duration = (inst_category.duration_days.to_i > 0) ? inst_category.duration_days.to_i : 30
          end_date = data[:end_date].present? ? Date.parse(data[:end_date]) : (start_date + (duration - 1).days)
          assignment_type = data[:assignment_type].presence || "individual"
          title = data[:title].presence || category.name
          description = data[:description].presence || category.description

          # Clone bundles for the institution category with custom overrides
          bundle_map = {} # client_bundle_id_or_master_id => inst_bundle
          has_bundles_param = data[:custom_setup] == "1" || data["custom_setup"] == "1" || data.key?(:bundles) || data.key?("bundles")
          bundles_param = data[:bundles] || data["bundles"]

          if has_bundles_param
            if bundles_param.present?
              pos = 0
              bundles_param.each do |b_key, b_data|
                b_hash = b_data.respond_to?(:to_unsafe_h) ? b_data.to_unsafe_h : b_data
                b_name = (b_hash[:name] || b_hash["name"]).to_s.strip
                next if b_name.blank?

                b_from = (b_hash[:from_day] || b_hash["from_day"]).to_i
                b_to = (b_hash[:to_day] || b_hash["to_day"]).to_i
                b_desc = (b_hash[:description] || b_hash["description"]).to_s.presence

                m_bundle = category.question_bundles.find_by(id: b_key)

                inst_bundle = inst_category.question_bundles.create!(
                  name: b_name,
                  description: b_desc || m_bundle&.description,
                  position: pos += 1,
                  from_day: b_from > 0 ? b_from : (m_bundle&.from_day || 1),
                  to_day: b_to > 0 ? b_to : (m_bundle&.to_day || duration)
                )
                bundle_map[b_key.to_s] = inst_bundle
                bundle_map[m_bundle.id.to_s] = inst_bundle if m_bundle
                bundle_map[m_bundle.id] = inst_bundle if m_bundle
              end
            end
          else
            category.question_bundles.order(:position).each do |m_bundle|
              inst_bundle = inst_category.question_bundles.create!(
                name: m_bundle.name,
                description: m_bundle.description,
                position: m_bundle.position,
                from_day: m_bundle.from_day || 1,
                to_day: m_bundle.to_day || duration
              )
              bundle_map[m_bundle.id] = inst_bundle
              bundle_map[m_bundle.id.to_s] = inst_bundle
            end
          end

          # Clone master questions for current institute under inst_category
          question_map = {} # master_q.id => inst_q
          questions_override_param = data[:questions] || data["questions"] || {}

          category.questions.each do |m_q|
            q_override = questions_override_param[m_q.id.to_s] || questions_override_param[m_q.id]
            if m_q.institute_id == current_institute.id
              inst_q = m_q
            else
              inst_q = m_q.deep_clone_for_institute(current_institute, inst_category)
            end

            if q_override.present?
              q_hash = q_override.respond_to?(:to_unsafe_h) ? q_override.to_unsafe_h : q_override
              inst_q.title = q_hash[:title] if q_hash[:title].present?
              inst_q.display_name = q_hash[:display_name] if q_hash.key?(:display_name)
              inst_q.from_day = q_hash[:from_day].to_i if q_hash[:from_day].to_i > 0
              inst_q.to_day = q_hash[:to_day].to_i if q_hash[:to_day].to_i > 0
              inst_q.description = q_hash[:description] if q_hash.key?(:description)
              inst_q.save!
            end

            question_map[m_q.id] = inst_q
          end

          # Reconnect QuestionBundleItems for institute bundles and cloned questions
          bundle_items = data[:bundle_items] || data["bundle_items"]
          if bundle_items.present?
            item_positions = Hash.new(0)
            added_bundle_question_ids = Set.new

            bundle_items.each do |bi|
              bi_hash = bi.respond_to?(:to_unsafe_h) ? bi.to_unsafe_h : bi
              orig_qid = (bi_hash[:question_id] || bi_hash["question_id"]).to_i
              b_name = (bi_hash[:bundle_name] || bi_hash["bundle_name"]).to_s.strip
              next if orig_qid.zero? || b_name.blank?

              inst_bundle = inst_category.question_bundles.find_by(name: b_name)
              next unless inst_bundle

              inst_q = question_map[orig_qid] || Question.find_by(id: orig_qid)
              next unless inst_q
              next if added_bundle_question_ids.include?([inst_bundle.id, inst_q.id])

              # Ensure question day range covers the assigned bundle range
              q_f = inst_q.from_day || 1
              q_t = inst_q.to_day || duration
              b_f = inst_bundle.from_day || 1
              b_t = inst_bundle.to_day || duration

              if [q_f, b_f].max > [q_t, b_t].min
                inst_q.from_day = [q_f, b_f].min
                inst_q.to_day = [q_t, b_t].max
                inst_q.save!
              end

              eff_from = [inst_q.from_day || 1, b_f].max
              eff_to = [inst_q.to_day || duration, b_t].min

              item_positions[inst_bundle.id] += 1
              inst_bundle.question_bundle_items.create!(
                question: inst_q,
                position: item_positions[inst_bundle.id],
                effective_from_day: eff_from,
                effective_to_day: eff_to
              )
              added_bundle_question_ids.add([inst_bundle.id, inst_q.id])
            end
          else
            category.question_bundles.each do |m_bundle|
              inst_bundle = bundle_map[m_bundle.id]
              next unless inst_bundle

              m_bundle.question_bundle_items.order(:position).each do |m_item|
                inst_q = question_map[m_item.question_id]
                next unless inst_q

                inst_bundle.question_bundle_items.create!(
                  question: inst_q,
                  position: m_item.position,
                  effective_from_day: m_item.effective_from_day,
                  effective_to_day: m_item.effective_to_day
                )
              end
            end
          end

          assignment = current_institute.assignments.build(
            title: title,
            description: description,
            start_date: start_date,
            end_date: end_date,
            assignment_type: assignment_type,
            active: data[:active].nil? ? true : (data[:active] == "1" || data[:active] == true),
            question_category: inst_category
          )

          assignment.save!(validate: false)

          order_index = 0
          imported_pairs = Set.new
          has_q_param = data.key?(:question_ids) || data.key?("question_ids")
          selected_qids = (data[:question_ids] || data["question_ids"])&.map(&:to_i)&.reject(&:zero?) || []

          if bundle_items.present?
            bundle_items.each do |bi|
              bi_hash = bi.respond_to?(:to_unsafe_h) ? bi.to_unsafe_h : bi
              orig_qid = (bi_hash[:question_id] || bi_hash["question_id"]).to_i
              b_name = (bi_hash[:bundle_name] || bi_hash["bundle_name"]).to_s.strip
              next if orig_qid.zero? || b_name.blank?
              next if has_q_param && !selected_qids.include?(orig_qid)

              # Only assign to bundle if the bundle actually exists in inst_category
              inst_bundle = inst_category.question_bundles.find_by(name: b_name)
              next unless inst_bundle

              target_q = question_map[orig_qid]
              if target_q.nil?
                target_q = Question.find_by(id: orig_qid)
                if target_q && target_q.institute_id != current_institute.id
                  target_q = target_q.deep_clone_for_institute(current_institute, inst_category)
                  question_map[orig_qid] = target_q
                end
              end

              next if target_q.nil? || imported_pairs.include?([target_q.id, b_name])

              assignment.assignment_questions.create!(
                question_id: target_q.id,
                bundle_name: b_name,
                order_number: order_index += 1
              )
              imported_pairs.add([target_q.id, b_name])
            end
          else
            inst_category.question_bundles.order(:position).each do |inst_bundle|
              inst_bundle.question_bundle_items.order(:position).each do |item|
                target_q = item.question
                next if target_q.nil? || imported_pairs.include?([target_q.id, inst_bundle.name])

                orig_master_qid = question_map.key(target_q) || target_q.id
                if !has_q_param || selected_qids.include?(target_q.id) || selected_qids.include?(orig_master_qid)
                  assignment.assignment_questions.create!(
                    question_id: target_q.id,
                    bundle_name: inst_bundle.name,
                    order_number: order_index += 1
                  )
                  imported_pairs.add([target_q.id, inst_bundle.name])
                end
              end
            end
          end

          # If inst_category has no bundles (all deleted or none exist), assign selected questions unbundled
          if inst_category.question_bundles.empty? && has_q_param && selected_qids.any?
            selected_qids.each do |orig_qid|
              target_q = question_map[orig_qid] || Question.find_by(id: orig_qid)
              next if target_q.nil? || imported_pairs.include?([target_q.id, nil])

              assignment.assignment_questions.create!(
                question_id: target_q.id,
                bundle_name: nil,
                order_number: order_index += 1
              )
              imported_pairs.add([target_q.id, nil])
            end
          end

          if assignment_type == "section"
            sec_ids = data[:section_ids]&.reject(&:blank?) || []
            sec_ids.uniq.each do |sid|
              assignment.assignment_sections.create!(section_id: sid)
            end

            part_ids = data[:participant_ids]&.reject(&:blank?) || []
            if part_ids.any?
              part_ids.uniq.each do |pid|
                assignment.assignment_participants.create!(participant_id: pid)
              end
            elsif sec_ids.any?
              current_institute.participants.active.where(section_id: sec_ids).pluck(:id).each do |pid|
                assignment.assignment_participants.create!(participant_id: pid)
              end
            end
          else
            part_ids = data[:participant_ids]&.reject(&:blank?) || []
            part_ids.uniq.each do |pid|
              assignment.assignment_participants.create!(participant_id: pid)
            end
          end

          created_assignments << assignment
        end
      end

      titles_str = created_assignments.map(&:title).join(", ")
      redirect_to institute_admin_assignments_path, notice: "Successfully created #{created_assignments.size} assignment(s): #{titles_str}!"
    rescue => e
      Rails.logger.error("Failed to finalize Question Bank import: #{e.message}\n#{e.backtrace.join("\n")}")
      redirect_to institute_admin_assignments_path, alert: "An error occurred while creating assignments: #{e.message}"
    end

    def import_question_bank
      redirect_to import_setup_institute_admin_assignments_path(
        question_bank_id: params[:question_bank_id],
        category_ids: params[:category_ids]
      )
    end

    def show
      @grouped_questions = @assignment.questions_grouped_by_bundle
      @participants = @assignment.participants.includes(:user).ordered_by_name
    end

    def new
      @assignment = current_institute.assignments.new
      set_form_variables
    end

    def create
      cleaned_params = assignment_params.to_h
      cleaned_params["question_ids"]&.reject!(&:blank?)
      cleaned_params["question_set_ids"]&.reject!(&:blank?)
      cleaned_params["participant_ids"]&.reject!(&:blank?)

      question_bundle_items = cleaned_params.delete("question_bundle_items") || []
      question_ids = cleaned_params.delete("question_ids") || []
      question_set_ids = cleaned_params.delete("question_set_ids") || []
      participant_ids = cleaned_params.delete("participant_ids") || []

      @assignment = current_institute.assignments.new(cleaned_params)

      ActiveRecord::Base.transaction do
        if @assignment.save
          if question_bundle_items.any?
            added_pairs = Set.new
            order_idx = 0
            question_bundle_items.each do |item|
              qid = (item["question_id"] || item[:question_id]).to_i
              bname = (item["bundle_name"] || item[:bundle_name]).to_s.strip
              next if qid.zero? || bname.blank? || added_pairs.include?([qid, bname])

              target_q = Question.find_by(id: qid)
              if target_q && target_q.institute_id != current_institute.id
                target_q = target_q.deep_clone_for_institute(current_institute, @assignment.question_category)
              end
              next unless target_q

              added_pairs.add([target_q.id, bname])
              order_idx += 1
              @assignment.assignment_questions.build(question_id: target_q.id, bundle_name: bname, order_number: order_idx)
            end
          elsif question_ids.any?
            added_qids = Set.new
            order_idx = 0
            question_ids.each do |qid|
              qid_i = qid.to_i
              next if qid_i.zero? || added_qids.include?(qid_i)

              target_q = Question.find_by(id: qid_i)
              if target_q && target_q.institute_id != current_institute.id
                target_q = target_q.deep_clone_for_institute(current_institute, @assignment.question_category)
              end
              next unless target_q

              added_qids.add(target_q.id)
              order_idx += 1
              @assignment.assignment_questions.build(question_id: target_q.id, order_number: order_idx)
            end
          end

          question_set_ids.uniq.reject(&:blank?).each do |qsid|
            @assignment.assignment_question_sets.build(question_set_id: qsid)
          end

          participant_ids.uniq.reject(&:blank?).each do |pid|
            @assignment.assignment_participants.build(participant_id: pid)
          end

          if @assignment.assignment_questions.all?(&:valid?) &&
             @assignment.assignment_question_sets.all?(&:valid?) &&
             @assignment.assignment_participants.all?(&:valid?)

            @assignment.assignment_questions.each(&:save!)
            @assignment.assignment_question_sets.each(&:save!)
            @assignment.assignment_participants.each(&:save!)

            if @assignment.valid?
              redirect_to institute_admin_assignments_path, notice: "Assignment created successfully."
              return
            end
          end

          raise ActiveRecord::Rollback
        end
      end

      Rails.logger.debug "Assignment creation failed: #{@assignment.errors.full_messages}"
      set_form_variables
      render :new
    end

    def edit
      set_form_variables
    end

    def update
      cleaned_params = assignment_params.to_h
      cleaned_params["question_ids"]&.reject!(&:blank?)
      cleaned_params["question_set_ids"]&.reject!(&:blank?)
      cleaned_params["participant_ids"]&.reject!(&:blank?)

      question_bundle_items = cleaned_params.delete("question_bundle_items") || []
      question_ids = cleaned_params.delete("question_ids") || []
      question_set_ids = cleaned_params.delete("question_set_ids") || []
      participant_ids = cleaned_params.delete("participant_ids") || []
      section_ids = cleaned_params.delete("section_ids") || []

      @assignment.assign_attributes(cleaned_params)

      ActiveRecord::Base.transaction do
        @assignment.assignment_questions.destroy_all
        @assignment.assignment_question_sets.destroy_all
        @assignment.assignment_participants.destroy_all
        @assignment.assignment_sections.destroy_all

          if question_bundle_items.any?
            added_pairs = Set.new
            order_idx = 0
            question_bundle_items.each do |item|
              qid = (item["question_id"] || item[:question_id]).to_i
              bname = (item["bundle_name"] || item[:bundle_name]).to_s.strip
              next if qid.zero? || bname.blank? || added_pairs.include?([qid, bname])

              target_q = Question.find_by(id: qid)
              if target_q && target_q.institute_id != current_institute.id
                target_q = target_q.deep_clone_for_institute(current_institute, @assignment.question_category)
              end
              next unless target_q

              added_pairs.add([target_q.id, bname])
              order_idx += 1
              @assignment.assignment_questions.build(question_id: target_q.id, bundle_name: bname, order_number: order_idx)
            end
          elsif question_ids.any?
            added_qids = Set.new
            order_idx = 0
            question_ids.each do |qid|
              qid_i = qid.to_i
              next if qid_i.zero? || added_qids.include?(qid_i)

              target_q = Question.find_by(id: qid_i)
              if target_q && target_q.institute_id != current_institute.id
                target_q = target_q.deep_clone_for_institute(current_institute, @assignment.question_category)
              end
              next unless target_q

              added_qids.add(target_q.id)
              order_idx += 1
              @assignment.assignment_questions.build(question_id: target_q.id, order_number: order_idx)
            end
          end

        question_set_ids.uniq.reject(&:blank?).each do |qsid|
          @assignment.assignment_question_sets.build(question_set_id: qsid)
        end

        participant_ids.uniq.reject(&:blank?).each do |pid|
          @assignment.assignment_participants.build(participant_id: pid)
        end

        section_ids.uniq.reject(&:blank?).each do |sec_id|
          @assignment.assignment_sections.build(section_id: sec_id)
        end

        if @assignment.save
          redirect_to institute_admin_assignment_path(@assignment), notice: "Assignment updated successfully."
          return
        else
          raise ActiveRecord::Rollback
        end
      end

      set_form_variables
      render :edit, status: :unprocessable_entity
    end

    def destroy
      if @assignment.destroy
        redirect_to institute_admin_assignments_path, notice: "Assignment was successfully deleted."
      else
        redirect_to institute_admin_assignments_path, alert: @assignment.errors.full_messages.to_sentence.presence || "Assignment could not be deleted."
      end
    end

    private

    def set_form_variables
      @sections = current_institute.sections.active.order(:name)
      @selected_sections = @assignment.sections.order(:name)
      @selected_participants = @assignment.participants.includes(:user).ordered_by_name
      @participants = current_institute.participants.active.includes(:user).ordered_by_name
      @grouped_questions = @assignment.edit_questions_grouped_by_bundle
      @custom_questions = current_institute.questions.includes(:options).order(position: :asc, created_at: :asc, id: :asc)
      @available_question_banks = QuestionBank.where(active: true).includes(:question_categories).order(:name)
    end

    def set_assignment
      @assignment = current_institute.assignments
        .includes(:question_category)
        .find(params[:id])
    end

    def assignment_params
      params.require(:assignment).permit(
        :title, :description, :start_date, :end_date, :active, :assignment_type,
        :section_id, :question_category_id,
        section_ids: [],
        participant_ids: [],
        question_ids: [],
        question_set_ids: [],
        question_bundle_items: [:question_id, :bundle_name]
      )
    end
  end
end
