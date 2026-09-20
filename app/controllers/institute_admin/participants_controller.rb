require "csv"
require "securerandom"

module InstituteAdmin
  class ParticipantsController < InstituteAdmin::BaseController
    before_action :set_participant, only: [ :show, :edit, :destroy, :toggle_status ]
    before_action :set_sections, only: [ :new, :create, :edit, :update ]

    def index
      @participants = current_institute.participants.includes(:section, :guardian_for_participant, user: :section).order(created_at: :desc)
      @sections = current_institute.sections.order(:name)

      # Score card metrics for approved participants
      base_approved = current_institute.participants.joins(:user).where(users: { active: true })
      @total_approved_count = base_approved.count
      @approved_by_type = base_approved.group(:participant_type).count
      @total_sections_count = current_institute.sections.count

      # Filter by approval status
      if params[:approved] == "false"
        @participants = @participants.joins(:user).where(users: { active: false })
        @approval_status = "not_approved"
      else
        # Default is to show approved participants
        @participants = @participants.joins(:user).where(users: { active: true })
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
        @selected_participant_types = [params[:participant_type].to_s]
      end
      if @selected_participant_types.present? && !@selected_participant_types.include?("all")
        @participants = @participants.where(participant_type: @selected_participant_types)
      end

      # Filter by sections (multi-select with backward compatibility)
      @selected_section_ids = parse_multiselect_param(params[:section_ids])
      if @selected_section_ids.empty? && params[:section_id].present? && params[:section_id] != "all"
        @selected_section_ids = [params[:section_id].to_s]
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
        if @user.destroy
          redirect_to institute_admin_participants_path,
            notice: "Participant was successfully deleted."
        else
          redirect_to institute_admin_participants_path,
            alert: "Failed to delete participant: #{@user.errors.full_messages.to_sentence}"
        end
      rescue ActiveRecord::InvalidForeignKey => e
        redirect_to institute_admin_participants_path,
          alert: "Cannot delete participant because it is referenced by other records. Please remove those associations first."
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
      # Toggle the active status
      @user.active = !@user.active

      if @user.save
        status_message = @user.active? ? "approved" : "unapproved"
        redirect_back fallback_location: institute_admin_participants_path,
          notice: "Participant was successfully #{status_message}."
      else
        redirect_back fallback_location: institute_admin_participants_path,
          alert: "Failed to update participant status: #{@user.errors.full_messages.to_sentence}"
      end
    end

    def approve_all
      # Get all not approved participants for the current institute
      not_approved_users = current_institute.users
                          .where(role: :participant, active: false)
                          .joins(:participant)

      # Approve all participants
      count = 0
      not_approved_users.find_each do |user|
        user.active = true
        count += 1 if user.save
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

      users = current_institute.users.where(id: ids, role: :participant, active: false)
      count = 0
      users.find_each do |user|
        user.active = true
        count += 1 if user.save
      end

      if count > 0
        redirect_to institute_admin_participants_path(approved: true),
          notice: "Successfully approved #{count} participant#{count > 1 ? 's' : ''}."
      else
        redirect_to institute_admin_participants_path(approved: false),
          alert: "No participants were approved."
      end
    end

    private

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
