module Admin
  class InstitutesController < Admin::BaseController
    before_action :set_institute, only: [ :show, :edit, :update, :login_as_institute_admin ]
    skip_before_action :authenticate_user!, only: [ :sections ]

    def index
      @institutes = Institute.all
      @status_filter = %w[all active inactive].include?(params[:status]) ? params[:status] : "active"
    end

    def show
      @institute_admins = @institute.users.institute_admin
      @available_admins = User.institute_admin.where(institute_id: nil)
    end

    def new
      @institute = Institute.new
    end

    def create
      @institute = Institute.new(institute_params)

      if @institute.save
        redirect_to admin_institutes_path, notice: "Institute was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      permitted = institute_params
      if permitted.delete(:remove_logo) == "1" && @institute.logo.attached?
        @institute.logo.purge
      end
      if @institute.update(permitted)
        redirect_to admin_institute_path(@institute), notice: "Institute was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def assign_admin
      @institute = Institute.find(params[:id])
      @user = User.find(params[:user_id])

      if @user.update(institute_id: @institute.id)
        redirect_to admin_institute_path(@institute), notice: "Admin successfully assigned to institute."
      else
        redirect_to admin_institute_path(@institute), alert: "Failed to assign admin."
      end
    end

    def unassign_admin
      @institute = Institute.find(params[:id])
      @user = User.find(params[:user_id])

      if @user.update(institute_id: nil)
        redirect_to admin_institute_path(@institute), notice: "Admin successfully unassigned from institute."
      else
        redirect_to admin_institute_path(@institute), alert: "Failed to unassign admin."
      end
    end

    def login_as_institute_admin
      if current_user.master_admin?
        session[:admin_institute_id] = @institute.id
        session[:admin_return_to] = admin_institute_path(@institute)

        redirect_to institute_admin_root_path,
          notice: "You are now logged in as an institute admin for #{@institute.name}. Your actions will affect this institute."
      else
        redirect_to admin_institute_path(@institute),
          alert: "Only master admins can access this functionality."
      end
    end

    def sections
      Rails.logger.info "Fetching sections for institute_id: #{params[:institute_id]}"
      @sections = Section.where(institute_id: params[:institute_id])
      if @sections.any?
        render json: @sections
      else
        render json: { error: "No sections found for this institute." }, status: :not_found
      end
    end

    private

    def set_institute
      @institute = Institute.find(params[:id])
    end

    def institute_params
      params.require(:institute).permit(:name, :code, :description, :address, :contact_number, :email, :active, :institution_type,
                                       :registered_poc, :service_started_on, :owner_name, :age_of_service,
                                       :billing_type, :expiry_date, :other_details, :logo, :remove_logo)
    end
  end
end
