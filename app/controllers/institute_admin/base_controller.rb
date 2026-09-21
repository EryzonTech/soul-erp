module InstituteAdmin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_institute_admin
    before_action :deny_view_only_writes
    layout "institute_admin"

    private

    def require_institute_admin
      unless current_user&.institute_admin? || (current_user&.master_admin? && session[:admin_institute_id].present?)
        redirect_to root_path, alert: "You must be an institute admin to access this area."
      end
    end

    # Blocks write operations for institute admins with view-only privilege.
    # Master admins impersonating an institute are never view-only restricted.
    def deny_view_only_writes
      return unless current_user&.view_only_admin?

      # Allow all GET requests except write-intent actions (new/edit)
      write_actions = %w[new edit create update destroy
                         import_question_bank import_setup finalize_import
                         approve_all approve_selected toggle_status
                         update_status update_progress mark_completed
                         assign record reorder duplicate
                         create_certificate create_section_certificate
                         publish_multiple_certificates unpublish_multiple_certificates
                         delete_multiple_certificates regenerate_multiple_certificates
                         download_multiple_certificates toggle_publish_certificate
                         regenerate_certificate delete_certificate
                         export_async reassign_users].freeze

      if write_actions.include?(action_name) || !request.get?
        redirect_to institute_admin_root_path,
          alert: "You have view-only access and cannot perform this action."
      end
    end

    def current_institute
      if current_user.master_admin? && session[:admin_institute_id].present?
        @current_institute ||= Institute.find_by(id: session[:admin_institute_id])
      else
        @current_institute ||= current_user&.institute
      end
    end
    helper_method :current_institute

    # Expose view_only status to views/layouts.
    def current_user_view_only?
      current_user&.view_only_admin? && !current_user&.master_admin?
    end
    helper_method :current_user_view_only?
  end
end
