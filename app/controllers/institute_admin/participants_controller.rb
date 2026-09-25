require "csv"
require "securerandom"

module InstituteAdmin
  class ParticipantsController < InstituteAdmin::BaseController
    before_action :set_participant, only: [ :show, :edit, :destroy, :toggle_status ]
    before_action :set_sections, only: [ :new, :create, :edit, :update ]

    def index
      @participants = current_institute.participants
                                       .joins(:user)
                                       .includes(:section, :guardian_for_participant, user: :section)
                                       .order(Arel.sql("LOWER(TRIM(COALESCE(NULLIF(users.first_name, ''), users.email))) ASC, LOWER(TRIM(COALESCE(users.last_name, ''))) ASC"))
      @sections = current_institute.sections.order(:name)

      # Score card metrics for approved participants
      base_approved = current_institute.participants.joins(:user).where(users: { active: true }).where.not(status: :suspended)
      @total_approved_count = base_approved.count
      @approved_by_type = base_approved.group(:participant_type).count
      @total_sections_count = current_institute.sections.count

      # Filter by status / approval state
      if params[:status] == "suspended"
        @participants = @participants.where(status: :suspended)
        @approval_status = "suspended"
        base_suspended = current_institute.participants.where(status: :suspended)
        @total_suspended_count = base_suspended.count
        @suspended_by_type = base_suspended.group(:participant_type).count
      elsif params[:approved] == "false"
        @participants = @participants.where(users: { active: false }).where.not(status: :suspended)
        @approval_status = "not_approved"
      else
        # Default is to show approved participants (active and not suspended)
        @participants = @participants.where(users: { active: true }).where.not(status: :suspended)
        @approval_status = "approved"
      end

      # Filter by search (name or mobile number)
      if params[:search].present?
        search_term = "%#{params[:search].to_s.strip}%"
        @participants = @participants.joins(:user).where(
          "users.first_name ILIKE :q OR users.last_name ILIKE :q OR CONCAT(users.first_name, ' ', users.last_name) ILIKE :q OR users.phone ILIKE :q OR participants.phone_number ILIKE :q",
          q: search_term
        )
      end

      # Filter by participant types (multi-select with backward compatibility)
      @selected_participant_types = parse_multiselect_param(params[:participant_types])
      if @selected_participant_types.empty? && params[:participant_type].present? && params[:participant_type] != "all"
        @selected_participant_types = [ params[:participant_type].to_s ]
      end
      if @selected_participant_types.present? && !@selected_participant_types.include?("all")
        @participants = @participants.where(participant_type: @selected_participant_types)
      end

      # Filter by sections (multi-select with backward compatibility)
      @selected_section_ids = parse_multiselect_param(params[:section_ids])
      if @selected_section_ids.empty? && params[:section_id].present? && params[:section_id] != "all"
        @selected_section_ids = [ params[:section_id].to_s ]
      end
      if @selected_section_ids.present? && !@selected_section_ids.include?("all")
        @participants = @participants.where(section_id: @selected_section_ids)
      end

      # Add pagination
      @participants = @participants.page(params[:page]).per(20)
    end

    def show
      @user = @participant.user
      @guardian = @participant.guardian
    end

    def new
      @user = User.new
      @user.build_participant
      @linked_student_ids = []
    end

    def create
      @user = User.new(user_params)
      @user.institute = current_institute
      @user.role = :participant
      @user.phone = user_params[:participant_attributes][:phone_number]

      # Set institute for participant
      @user.participant.institute = current_institute if @user.participant

      # Set section ID for students and employees
      if params[:user][:participant_attributes][:participant_type].in?([ "student", "employee" ])
        @user.section_id = params[:user][:participant_attributes][:section_id]
      end

      # For guardians, set section from first selected student
      if params[:user][:participant_attributes][:participant_type] == "guardian"
        student_ids = Array(params[:user][:student_participant_ids]).reject(&:blank?).map(&:to_i)
        if student_ids.any?
          first_student = Participant.find_by(id: student_ids.first)
          @user.section_id = first_student.section_id if first_student
          # Store first student in legacy column too
          @user.participant.guardian_for_participant_id = student_ids.first
        end
      end

      if @user.save
        # Create join table records for all selected students
        if params[:user][:participant_attributes][:participant_type] == "guardian"
          student_ids = Array(params[:user][:student_participant_ids]).reject(&:blank?).map(&:to_i)
          student_ids.each do |sid|
            GuardianStudentLink.find_or_create_by!(
              guardian_participant_id: @user.participant.id,
              student_participant_id: sid
            )
          end
        end
        redirect_to institute_admin_participants_path, notice: "Participant was successfully created."
      else
        set_sections
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @user = @participant.user
      @participant.institute = current_institute
      # Preload linked students for the form
      @linked_student_ids = @participant.student_participants.pluck(:id)
    end

    def update
      @user = User.find(params[:id])
      @participant = @user.participant

      @participant.institute = current_institute if @participant

      # Set section ID for students and employees
      if params[:user][:participant_attributes][:participant_type].in?([ "student", "employee" ])
        @user.section_id = params[:user][:participant_attributes][:section_id]
      end

      # For guardians, set section from first selected student
      if params[:user][:participant_attributes][:participant_type] == "guardian"
        student_ids = Array(params[:user][:student_participant_ids]).reject(&:blank?).map(&:to_i)
        if student_ids.any?
          first_student = Participant.find_by(id: student_ids.first)
          @user.section_id = first_student.section_id if first_student
        end
      end

      if @user.update(user_params)
        # Sync guardian-student join table
        if @participant.guardian?
          student_ids = Array(params[:user][:student_participant_ids]).reject(&:blank?).map(&:to_i)
          # Remove deselected links
          @participant.guardian_student_links.where.not(student_participant_id: student_ids).destroy_all
          # Add new links
          student_ids.each do |sid|
            GuardianStudentLink.find_or_create_by!(
              guardian_participant_id: @participant.id,
              student_participant_id: sid
            )
          end
          # Keep legacy column in sync with first student
          @participant.update_column(:guardian_for_participant_id, student_ids.first)
        end
        redirect_to "#{institute_admin_participants_path}/?approved=#{@user.active}", notice: "Participant was successfully updated."
      else
        @linked_student_ids = @participant.student_participants.pluck(:id)
        set_sections
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      begin
        @participant.soft_delete!
        redirect_to institute_admin_participants_path,
          notice: "Participant was successfully deleted."
      rescue StandardError => e
        redirect_to institute_admin_participants_path,
          alert: "An error occurred: #{e.message}"
      end
    end

    def assignments
      @participant = current_institute.participants.find(params[:id])

      # Get assignments for this participant (both individual and section assignments)
      individual_assignments = Assignment.joins(:assignment_participants)
                                        .where(assignment_participants: { participant_id: @participant.id })

      section_assignments = Assignment.joins(:assignment_sections)
                                     .where(assignment_sections: { section_id: @participant.section_id })

      @assignments = Assignment.where(id: individual_assignments.pluck(:id) + section_assignments.pluck(:id))
                              .distinct.order(created_at: :desc)

      respond_to do |format|
        format.json { render json: @assignments.map { |a| { id: a.id, title: a.title } } }
      end
    end

    def toggle_status
      # Toggle the active/suspended status
      new_active = nil
      new_status = nil

      if @participant.suspended?
        new_status = :active
        new_active = true
      elsif @user.active?
        new_status = :suspended
        new_active = false
      else
        # Was unapproved / pending approval -> approve it
        new_status = :active
        new_active = true
      end

      ActiveRecord::Base.transaction do
        @participant.update_columns(status: Participant.statuses[new_status], updated_at: Time.current)
        @user.update_columns(active: new_active, updated_at: Time.current)
      end

      status_message = new_active ? "activated" : "suspended"
      redirect_back fallback_location: institute_admin_participants_path,
        notice: "Participant was successfully #{status_message}."
    rescue => e
      redirect_back fallback_location: institute_admin_participants_path,
        alert: "Failed to update participant status: #{e.message}"
    end

    def approve_all
      # Get all not approved participants (excluding suspended) for the current institute
      not_approved_participants = current_institute.participants
                                                   .joins(:user)
                                                   .where(users: { active: false })
                                                   .where.not(status: :suspended)
                                                   .includes(:user)

      count = 0
      ActiveRecord::Base.transaction do
        not_approved_participants.find_each do |participant|
          participant.update_columns(status: Participant.statuses[:active], updated_at: Time.current)
          if participant.user
            participant.user.update_columns(active: true, updated_at: Time.current)
            count += 1
          end
        end
      end

      if count > 0
        redirect_to institute_admin_participants_path(approved: true),
          notice: "Successfully approved #{count} participant#{count > 1 ? 's' : ''}."
      else
        redirect_to institute_admin_participants_path(approved: false),
          alert: "No participants were approved."
      end
    end

    # Approve a selected list of participants (bulk approve)
    def approve_selected
      ids = params[:selected_ids].to_s.split(",").map(&:strip).reject(&:blank?)
      if ids.empty?
        redirect_to institute_admin_participants_path(approved: false), alert: "No participants selected." and return
      end

      participants = resolve_participants(ids)

      count = 0
      ActiveRecord::Base.transaction do
        participants.each do |p|
          p.update_columns(status: Participant.statuses[:active], updated_at: Time.current)
          if p.user && !p.user.active?
            p.user.update_columns(active: true, updated_at: Time.current)
            count += 1
          end
        end
      end

      if count > 0
        redirect_to institute_admin_participants_path(approved: true),
          notice: "Successfully approved #{count} participant#{count > 1 ? 's' : ''}."
      else
        redirect_to institute_admin_participants_path(approved: false),
          alert: "No participants were approved."
      end
    end

    # Deactivate / suspend a selected list of participants (bulk suspend)
    def deactivate_selected
      ids = params[:selected_ids].to_s.split(",").map(&:strip).reject(&:blank?)
      if ids.empty?
        redirect_to institute_admin_participants_path(approved: true), alert: "No participants selected." and return
      end

      participants = resolve_participants(ids)

      count = 0
      ActiveRecord::Base.transaction do
        participants.each do |p|
          p.update_columns(status: Participant.statuses[:suspended], updated_at: Time.current)
          if p.user && p.user.active?
            p.user.update_columns(active: false, updated_at: Time.current)
            count += 1
          end
        end
      end

      if count > 0
        redirect_to institute_admin_participants_path(approved: true),
          notice: "Successfully suspended #{count} participant#{count > 1 ? 's' : ''}."
      else
        redirect_to institute_admin_participants_path(approved: true),
          alert: "No participants were suspended."
      end
    end

    # Reactivate a selected list of suspended participants (bulk reactivate)
    def reactivate_selected
      ids = params[:selected_ids].to_s.split(",").map(&:strip).reject(&:blank?)
      if ids.empty?
        redirect_to institute_admin_participants_path(status: "suspended"), alert: "No participants selected." and return
      end

      participants = resolve_participants(ids).where(status: :suspended)

      count = 0
      ActiveRecord::Base.transaction do
        participants.each do |p|
          p.update_columns(status: Participant.statuses[:active], updated_at: Time.current)
          if p.user && !p.user.active?
            p.user.update_columns(active: true, updated_at: Time.current)
            count += 1
          end
        end
      end

      if count > 0
        redirect_to institute_admin_participants_path(status: "suspended"),
          notice: "Successfully reactivated #{count} participant#{count > 1 ? 's' : ''}."
      else
        redirect_to institute_admin_participants_path(status: "suspended"),
          alert: "No participants were reactivated."
      end
    end

    private

    def resolve_participants(ids)
      participants = current_institute.participants.where(id: ids).includes(:user)
      if participants.count < ids.size
        found_p_ids = participants.pluck(:id).map(&:to_s)
        found_u_ids = participants.map(&:user_id).compact.map(&:to_s)
        remaining_ids = ids.map(&:to_s) - found_p_ids - found_u_ids
        if remaining_ids.any?
          user_id_participants = current_institute.participants.where(user_id: remaining_ids).includes(:user)
          participants = participants.or(user_id_participants)
        end
      end
      participants
    end

    def set_participant
      # Try to find the participant directly through the institute's participants
      @participant = current_institute.participants.find_by(id: params[:id])
      @user = @participant.user

      # Raise RecordNotFound if neither approach found a participant
      raise ActiveRecord::RecordNotFound unless @participant && @user
    end

    def set_sections
      @sections = current_institute.sections.active
    end

    def user_params
      params.require(:user).permit(
        :first_name,
        :last_name,
        :email,
        :password,
        :password_confirmation,
        :section_id,
        participant_attributes: [
          :id,
          :date_of_birth,
          :phone_number,
          :section_id,
          :status,
          :institute_id,
          :participant_type,
          :job_role,
          :qualification,
          :years_of_experience,
          :enrollment_date,
          :guardian_for_participant_id,
          :address,
          :address_line1,
          :address_line2,
          :place,
          :pin_code,
          :district,
          :state
        ]
      )
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
  end
end
