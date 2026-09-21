Rails.application.routes.draw do
  namespace :institute_admin do
    resources :certificate_configurations
  end
  # Move this to the top, before any authenticate blocks
  get "/sections/fetch", to: "institute_admin/sections#fetch"

  # Root path first
  root "home#index"

  # Devise routes with custom paths
  devise_for :users, path: "", path_names: {
    sign_in: "login",
    sign_out: "logout",
    sign_up: "register"
  }, controllers: {
    registrations: "registrations"
  }, skip: [ :sessions ]  # Skip sessions routes

  # Custom session routes
  devise_scope :user do
    get "login" => "devise/sessions#new", as: :new_user_session
    post "login" => "devise/sessions#create", as: :user_session
    delete "logout" => "devise/sessions#destroy", as: :destroy_user_session
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Silence Chrome DevTools well-known probe (returns empty JSON, no log spam)
  get "/.well-known/appspecific/com.chrome.devtools.json",
      to: proc { [ 200, { "Content-Type" => "application/json" }, [ "{}" ] ] }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Admin routes
  authenticate :user do
    namespace :admin do
  root "admin#dashboard"
  # Admin-level quick lists for Questions / Assignments / Trainers
  get "questions", to: "admin#questions", as: "questions"
  get "assignments", to: "admin#assignments", as: "assignments"
  get "trainers", to: "admin#trainers", as: "trainers"
      # Per-institute drilldown pages (master admin)
      get "institutes/:id/participants", to: "admin#institute_participants", as: "institute_participants"
      get "institutes/:id/programs", to: "admin#institute_programs", as: "institute_programs"
      get "participants_by_institute", to: "admin#participants_by_institute", as: "participants_by_institute"
      get "programs_by_institute", to: "admin#programs_by_institute", as: "programs_by_institute"
  # Responses overview and per-institute responses
  get "responses", to: "admin#responses", as: "responses"
  get "institutes/:id/responses", to: "admin#institute_responses", as: "institute_responses"
  get "institutes/:institute_id/responses/:id", to: "admin#response_detail", as: "institute_response_detail"
      resources :institutes do
        member do
          post "assign_admin"
          delete "unassign_admin"
          post "login_as_institute_admin"
        end
        resources :sections
      end
      resources :users
      resources :training_programs
      resources :assignments
      resource :registration_setting, only: [ :edit, :update ]

      resources :question_banks
      resources :question_categories do
        member do
          get :builder
          post :auto_assign_bundles
        end
        resources :imports, controller: "question_category_imports", only: [ :index, :new, :create, :show ] do
          collection do
            get :sample_template
            get :sample_excel_template
            get :blank_template
            get :blank_excel_template
          end
          member do
            get :status
            get :failed_rows
          end
        end
        resources :questions, controller: "category_questions" do
          collection do
            post :reorder
          end
          member do
            post :duplicate
          end
        end
        resources :bundles, controller: "question_bundles" do
          member do
            post :add_question
            delete "remove_question/:question_id", action: :remove_question, as: :remove_question
            post :reorder_questions
          end
        end
      end

      resources :question_imports, only: [ :index, :show ]
    end
  end

  # Institute Admin routes
  # We can't directly access session in the route constraints,
  # but the controller's before_action will handle the proper authorization
  authenticate :user, lambda { |u| u.institute_admin? || u.master_admin? } do
    namespace :institute_admin do
      root "dashboard#index"
      get "dashboard/chart_data", to: "dashboard#chart_data"
      get "dashboard/streak_leaderboards", to: "dashboard#streak_leaderboards"

      # Add profile routes
      get "profile", to: "profile#show"

      # Add settings routes
      resources :settings, only: [ :index ]
      get "general_settings", to: "general_settings#index", as: "general_settings"
      patch "general_settings", to: "general_settings#update"

      resources :sections do
        member do
          get :reassign_users
          post :reassign_users
          get :participants
          post :duplicate
        end
      end

      resources :trainers
      resources :participants do
        member do
          get :assignments
          patch :toggle_status
        end
        collection do
          patch :approve_all
          patch :approve_selected
        end
      end
      resources :questions do
        member do
          post :duplicate
        end
        collection do
          post :reorder
        end
      end
      resources :question_sets
      resources :training_programs do
        resources :training_program_feedbacks, only: [ :index ], path: "feedbacks"
        resources :attendances, only: [ :index, :new, :create ]
        member do
          patch :update_status
          patch :update_progress
          patch :mark_completed
        end
      end
      resources :attendances, only: [ :index ] do
        collection do
          get :list
          get :export_history_csv
          get :export_status_csv
        end
        member do
          get :mark
          post :record
          get :edit
          patch :update
          get :history
          get :check_status
        end
      end
      resources :assignments do
        collection do
          post :import_question_bank
          match :import_setup, via: [ :get, :post ]
          post :finalize_import
        end
        resources :responses, only: [ :index, :show ]
      end
      resources :responses do
        get "section/:section_id", action: :index, on: :collection
        get "section/:section_id/participant/:participant_id", action: :index, on: :collection
      end
      resources :reports, only: [ :index ] do
        collection do
          get "assignment_reports_menu"
          get "assignment_reports"
          get "individual_assignment_reports"
          get "consolidated_response_report"
          get "consolidated_matrix_report"
          get "assignment_response_details"
          match "export_async", via: [ :get, :post, :delete ]
          get "export_status"
          get "download_export"
          get "feedback_reports_menu"
          get "feedback_reports"
          get "section_feedback_reports"
          get "individual_feedback_reports"
          get "certificates"
          get "certificate_stats"
          get "generate_certificate"
          get "generate_section_certificate"
          post "create_section_certificate"
          post "create_certificate"
          get "view_certificates"
          get "certificate/:id", to: "reports#show_certificate", as: "view_certificate"
          get "show_certificate/:id", to: "reports#show_certificate", as: "show_certificate"
          get "download_certificate/:id", to: "reports#show_certificate", as: "download_certificate"
          delete "certificate/:id", to: "reports#delete_certificate", as: "delete_certificate"
          post "certificate/:id/regenerate", to: "reports#regenerate_certificate", as: "regenerate_certificate"
          post :publish_multiple_certificates
          post :delete_multiple_certificates
          post :unpublish_multiple_certificates
          post :download_multiple_certificates
          post :regenerate_multiple_certificates
        end
        member do
          post :toggle_publish_certificate
          get :show_certificate_on_demand
          get :download_certificate_on_demand
        end
      end
    end
  end

  # Trainer Portal routes
  authenticate :user do
    namespace :trainer_portal do
      root "dashboard#index"

      # Add profile routes
      get "profile", to: "profile#show"

      resources :training_programs do
        resources :attendances, only: [ :index, :new, :create ]
        member do
          patch :mark_completed
        end
      end

      resources :attendances, only: [ :index ] do
        collection do
          get :list
          get :export_history_csv
          get :export_status_csv
        end
        member do
          get :mark
          post :record
          get :edit
          patch :update
          get :history
          get :check_status
        end
      end

      resources :training_program_feedbacks, only: [ :index, :show ], path: "feedbacks"
    end
  end

  # Participant routes
  authenticate :user do
    namespace :participant_portal do
      root "dashboard#index"

      resources :analytics, only: [ :index ]
      resources :certificates, only: [ :index, :show ]

      resources :training_programs, only: [ :index, :show ] do
        resources :sessions, only: [ :show ]
        resources :feedbacks, only: [ :new, :create ], controller: "training_program_feedbacks"
      end
      resources :questions
      resources :assignments do
        member do
          get :take_assignment
          post :submit
        end
      end
      resource :profile, only: [ :show ]
      get "my_student/:student_id", to: "profiles#student_info", as: :student_info

      # Guardian student-view switcher
      post "student_view/:student_id", to: "student_views#switch", as: :switch_to_student_view
      delete "student_view", to: "student_views#return_to_guardian", as: :return_to_guardian_view
    end
  end
end
