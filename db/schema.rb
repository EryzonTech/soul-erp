# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_25_062544) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assignment_participants", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "participant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id", "participant_id"], name: "index_assignment_participants_uniqueness", unique: true
    t.index ["assignment_id"], name: "index_assignment_participants_on_assignment_id"
    t.index ["participant_id"], name: "index_assignment_participants_on_participant_id"
  end

  create_table "assignment_question_sets", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "question_set_id", null: false
    t.integer "order_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id", "question_set_id"], name: "index_assignment_question_sets_uniqueness", unique: true
    t.index ["assignment_id"], name: "index_assignment_question_sets_on_assignment_id"
    t.index ["question_set_id"], name: "index_assignment_question_sets_on_question_set_id"
  end

  create_table "assignment_questions", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "question_id", null: false
    t.integer "order_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bundle_name"
    t.index ["assignment_id", "question_id", "bundle_name"], name: "index_assignment_questions_uniqueness", unique: true
    t.index ["assignment_id"], name: "index_assignment_questions_on_assignment_id"
    t.index ["question_id"], name: "index_assignment_questions_on_question_id"
  end

  create_table "assignment_response_logs", force: :cascade do |t|
    t.bigint "institute_id", null: false
    t.bigint "participant_id", null: false
    t.datetime "response_date"
    t.bigint "assignment_id", null: false
    t.jsonb "assignment_response_ids", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "response_count"
    t.index ["assignment_id"], name: "index_assignment_response_logs_on_assignment_id"
    t.index ["institute_id", "response_date"], name: "index_assignment_response_logs_on_institute_and_date"
    t.index ["institute_id"], name: "index_assignment_response_logs_on_institute_id"
    t.index ["participant_id"], name: "index_assignment_response_logs_on_participant_id"
  end

  create_table "assignment_responses", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "participant_id", null: false
    t.bigint "question_id", null: false
    t.text "answer"
    t.jsonb "selected_options"
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "response_date"
    t.index ["assignment_id", "participant_id", "question_id", "response_date"], name: "index_assignment_responses_unique", unique: true
    t.index ["assignment_id"], name: "index_assignment_responses_on_assignment_id"
    t.index ["participant_id"], name: "index_assignment_responses_on_participant_id"
    t.index ["question_id"], name: "index_assignment_responses_on_question_id"
    t.index ["response_date", "participant_id"], name: "index_assignment_responses_on_date_and_participant"
    t.index ["response_date"], name: "index_assignment_responses_on_response_date"
  end

  create_table "assignment_sections", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.bigint "section_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_assignment_sections_on_assignment_id"
    t.index ["section_id"], name: "index_assignment_sections_on_section_id"
  end

  create_table "assignments", force: :cascade do |t|
    t.bigint "institute_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "start_date", null: false
    t.datetime "end_date", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "assignment_type", default: "individual"
    t.integer "section_id"
    t.bigint "question_category_id"
    t.bigint "participant_id"
    t.index ["institute_id"], name: "index_assignments_on_institute_id"
    t.index ["participant_id"], name: "index_assignments_on_participant_id"
    t.index ["question_category_id"], name: "index_assignments_on_question_category_id"
    t.index ["section_id"], name: "index_assignments_on_section_id"
  end

  create_table "attendances", force: :cascade do |t|
    t.bigint "training_program_id", null: false
    t.bigint "participant_id", null: false
    t.bigint "marked_by_id", null: false
    t.date "date", null: false
    t.integer "status", default: 0, null: false
    t.text "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["marked_by_id"], name: "index_attendances_on_marked_by_id"
    t.index ["participant_id"], name: "index_attendances_on_participant_id"
    t.index ["training_program_id", "participant_id", "date"], name: "index_attendances_uniqueness", unique: true
    t.index ["training_program_id"], name: "index_attendances_on_training_program_id"
  end

  create_table "certificate_configurations", force: :cascade do |t|
    t.string "name"
    t.text "details"
    t.integer "duration_period"
    t.bigint "institute_id", null: false
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "eligible_criteria"
    t.string "certificate_left_footer"
    t.string "certificate_right_footer"
    t.index ["institute_id"], name: "index_certificate_configurations_on_institute_id"
  end

  create_table "guardian_student_links", force: :cascade do |t|
    t.bigint "guardian_participant_id", null: false
    t.bigint "student_participant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guardian_participant_id", "student_participant_id"], name: "idx_guardian_student_unique", unique: true
    t.index ["guardian_participant_id"], name: "index_guardian_student_links_on_guardian_participant_id"
    t.index ["student_participant_id"], name: "index_guardian_student_links_on_student_participant_id"
  end

  create_table "guardians", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "participant_id", null: false
    t.string "relation"
    t.string "contact_number"
    t.string "occupation"
    t.text "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id"], name: "index_guardians_on_participant_id"
    t.index ["user_id"], name: "index_guardians_on_user_id"
  end

  create_table "individual_certificates", force: :cascade do |t|
    t.bigint "participant_id", null: false
    t.bigint "assignment_id", null: false
    t.bigint "certificate_configuration_id", null: false
    t.bigint "institute_id", null: false
    t.string "filename"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "published"
    t.text "chart_image_data"
    t.index ["assignment_id"], name: "index_individual_certificates_on_assignment_id"
    t.index ["certificate_configuration_id"], name: "index_individual_certificates_on_certificate_configuration_id"
    t.index ["institute_id"], name: "index_individual_certificates_on_institute_id"
    t.index ["participant_id"], name: "index_individual_certificates_on_participant_id"
  end

  create_table "institutes", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.text "description"
    t.string "address"
    t.string "contact_number"
    t.string "email"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "institution_type"
    t.string "registered_poc"
    t.date "service_started_on"
    t.string "owner_name"
    t.integer "age_of_service"
    t.string "billing_type"
    t.date "expiry_date"
    t.text "other_details"
  end

  create_table "options", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.boolean "correct", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.string "text"
    t.index ["question_id"], name: "index_options_on_question_id"
  end

  create_table "participants", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "section_id"
    t.bigint "institute_id", null: false
    t.date "date_of_birth"
    t.string "education_level"
    t.date "enrollment_date"
    t.integer "status", default: 0
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_number"
    t.string "participant_type"
    t.string "job_role"
    t.string "qualification"
    t.integer "years_of_experience"
    t.integer "guardian_for_participant_id"
    t.text "address"
    t.string "pin_code"
    t.string "district"
    t.string "state"
    t.string "address_line1"
    t.string "address_line2"
    t.string "place"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_participants_on_deleted_at"
    t.index ["institute_id", "participant_type"], name: "index_participants_on_institute_and_type"
    t.index ["institute_id"], name: "index_participants_on_institute_id"
    t.index ["phone_number"], name: "index_participants_on_phone_number"
    t.index ["section_id"], name: "index_participants_on_section_id"
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "question_banks", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "question_bundle_items", force: :cascade do |t|
    t.bigint "question_bundle_id", null: false
    t.bigint "question_id", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "effective_from_day"
    t.integer "effective_to_day"
    t.index ["question_bundle_id", "question_id"], name: "idx_qb_items_unique", unique: true
    t.index ["question_bundle_id"], name: "index_question_bundle_items_on_question_bundle_id"
    t.index ["question_id"], name: "index_question_bundle_items_on_question_id"
  end

  create_table "question_bundles", force: :cascade do |t|
    t.bigint "question_category_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "from_day", default: 1, null: false
    t.integer "to_day"
    t.index ["question_category_id"], name: "index_question_bundles_on_question_category_id"
  end

  create_table "question_categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "question_bank_id"
    t.integer "duration_days", default: 30, null: false
    t.bigint "institute_id"
    t.index ["institute_id"], name: "index_question_categories_on_institute_id"
    t.index ["question_bank_id"], name: "index_question_categories_on_question_bank_id"
  end

  create_table "question_imports", force: :cascade do |t|
    t.bigint "question_category_id", null: false
    t.bigint "user_id"
    t.string "filename"
    t.integer "file_size"
    t.integer "status", default: 0, null: false
    t.integer "total_rows", default: 0, null: false
    t.integer "successful_rows", default: 0, null: false
    t.integer "failed_rows", default: 0, null: false
    t.jsonb "error_log", default: []
    t.jsonb "process_log", default: []
    t.jsonb "imported_question_ids", default: []
    t.boolean "auto_assign_bundles", default: true, null: false
    t.boolean "dry_run", default: false, null: false
    t.boolean "rollback_on_error", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_category_id"], name: "index_question_imports_on_question_category_id"
    t.index ["status"], name: "index_question_imports_on_status"
    t.index ["user_id"], name: "index_question_imports_on_user_id"
  end

  create_table "question_set_items", force: :cascade do |t|
    t.bigint "question_set_id", null: false
    t.bigint "question_id", null: false
    t.integer "order_number"
    t.integer "marks_override"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_question_set_items_on_question_id"
    t.index ["question_set_id"], name: "index_question_set_items_on_question_set_id"
  end

  create_table "question_sets", force: :cascade do |t|
    t.bigint "institute_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "total_marks"
    t.integer "duration_minutes"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["institute_id"], name: "index_question_sets_on_institute_id"
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "institute_id"
    t.string "title", null: false
    t.text "description"
    t.integer "question_type", default: 0, null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "required", default: false
    t.integer "max_rating", default: 5
    t.string "display_name"
    t.integer "position", default: 0
    t.bigint "question_category_id"
    t.integer "options_count", default: 0, null: false
    t.integer "duration_days"
    t.integer "from_day", default: 1, null: false
    t.integer "to_day"
    t.bigint "participant_id"
    t.index ["institute_id"], name: "index_questions_on_institute_id"
    t.index ["participant_id"], name: "index_questions_on_participant_id"
    t.index ["question_category_id"], name: "index_questions_on_question_category_id"
  end

  create_table "registration_settings", force: :cascade do |t|
    t.text "enabled_institutes", default: "--- []", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sections", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.bigint "institute_id", null: false
    t.integer "capacity"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.index ["code", "institute_id"], name: "index_sections_on_code_and_institute_id", unique: true
    t.index ["institute_id"], name: "index_sections_on_institute_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "trainers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "institute_id", null: false
    t.string "specialization"
    t.string "qualification"
    t.integer "experience_years"
    t.text "bio"
    t.string "resume"
    t.json "certificates"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_number"
    t.text "experience_details"
    t.text "payment_details"
    t.text "other_details"
    t.index ["institute_id"], name: "index_trainers_on_institute_id"
    t.index ["phone_number"], name: "index_trainers_on_phone_number"
    t.index ["user_id"], name: "index_trainers_on_user_id"
  end

  create_table "training_program_feedbacks", force: :cascade do |t|
    t.bigint "training_program_id", null: false
    t.bigint "participant_id", null: false
    t.text "content", null: false
    t.integer "rating", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id"], name: "index_training_program_feedbacks_on_participant_id"
    t.index ["training_program_id", "participant_id"], name: "index_training_program_feedbacks_uniqueness", unique: true
    t.index ["training_program_id"], name: "index_training_program_feedbacks_on_training_program_id"
  end

  create_table "training_program_participants", force: :cascade do |t|
    t.bigint "training_program_id", null: false
    t.bigint "participant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id"], name: "index_training_program_participants_on_participant_id"
    t.index ["training_program_id", "participant_id"], name: "index_training_program_participants_uniqueness", unique: true
    t.index ["training_program_id"], name: "index_training_program_participants_on_training_program_id"
  end

  create_table "training_program_sections", force: :cascade do |t|
    t.bigint "training_program_id", null: false
    t.bigint "section_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["section_id"], name: "index_training_program_sections_on_section_id"
    t.index ["training_program_id", "section_id"], name: "index_training_program_sections_uniqueness", unique: true
    t.index ["training_program_id"], name: "index_training_program_sections_on_training_program_id"
  end

  create_table "training_programs", force: :cascade do |t|
    t.bigint "institute_id", null: false
    t.bigint "trainer_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer "program_type", default: 0, null: false
    t.bigint "section_id"
    t.bigint "participant_id"
    t.integer "status", default: 0
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "training_program_feedbacks_count", default: 0, null: false
    t.index ["institute_id", "program_type"], name: "index_training_programs_on_institute_id_and_program_type"
    t.index ["institute_id", "status"], name: "index_training_programs_on_institute_and_status"
    t.index ["institute_id"], name: "index_training_programs_on_institute_id"
    t.index ["participant_id"], name: "index_training_programs_on_participant_id"
    t.index ["section_id"], name: "index_training_programs_on_section_id"
    t.index ["trainer_id"], name: "index_training_programs_on_trainer_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: ""
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "username"
    t.integer "role"
    t.integer "institute_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true
    t.bigint "section_id"
    t.string "first_name"
    t.string "last_name"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "phone"
    t.boolean "view_only", default: false, null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["first_name", "last_name"], name: "index_users_on_first_name_and_last_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["section_id"], name: "index_users_on_section_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assignment_participants", "assignments"
  add_foreign_key "assignment_participants", "participants"
  add_foreign_key "assignment_question_sets", "assignments"
  add_foreign_key "assignment_question_sets", "question_sets"
  add_foreign_key "assignment_questions", "assignments"
  add_foreign_key "assignment_questions", "questions"
  add_foreign_key "assignment_response_logs", "assignments"
  add_foreign_key "assignment_response_logs", "institutes"
  add_foreign_key "assignment_response_logs", "participants"
  add_foreign_key "assignment_responses", "assignments"
  add_foreign_key "assignment_responses", "participants"
  add_foreign_key "assignment_responses", "questions"
  add_foreign_key "assignment_sections", "assignments"
  add_foreign_key "assignment_sections", "sections"
  add_foreign_key "assignments", "institutes"
  add_foreign_key "assignments", "participants"
  add_foreign_key "assignments", "question_categories"
  add_foreign_key "attendances", "participants"
  add_foreign_key "attendances", "training_programs"
  add_foreign_key "attendances", "users", column: "marked_by_id"
  add_foreign_key "certificate_configurations", "institutes"
  add_foreign_key "guardian_student_links", "participants", column: "guardian_participant_id"
  add_foreign_key "guardian_student_links", "participants", column: "student_participant_id"
  add_foreign_key "guardians", "participants"
  add_foreign_key "guardians", "users"
  add_foreign_key "individual_certificates", "assignments"
  add_foreign_key "individual_certificates", "certificate_configurations"
  add_foreign_key "individual_certificates", "institutes"
  add_foreign_key "individual_certificates", "participants"
  add_foreign_key "options", "questions"
  add_foreign_key "participants", "institutes"
  add_foreign_key "participants", "sections"
  add_foreign_key "participants", "users"
  add_foreign_key "question_bundle_items", "question_bundles"
  add_foreign_key "question_bundle_items", "questions"
  add_foreign_key "question_bundles", "question_categories"
  add_foreign_key "question_categories", "institutes"
  add_foreign_key "question_categories", "question_banks"
  add_foreign_key "question_imports", "question_categories"
  add_foreign_key "question_imports", "users"
  add_foreign_key "question_set_items", "question_sets"
  add_foreign_key "question_set_items", "questions"
  add_foreign_key "question_sets", "institutes"
  add_foreign_key "questions", "institutes"
  add_foreign_key "questions", "participants"
  add_foreign_key "questions", "question_categories"
  add_foreign_key "sections", "institutes"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "trainers", "institutes"
  add_foreign_key "trainers", "users"
  add_foreign_key "training_program_feedbacks", "participants"
  add_foreign_key "training_program_feedbacks", "training_programs"
  add_foreign_key "training_program_participants", "participants"
  add_foreign_key "training_program_participants", "training_programs"
  add_foreign_key "training_program_sections", "sections"
  add_foreign_key "training_program_sections", "training_programs"
  add_foreign_key "training_programs", "institutes"
  add_foreign_key "training_programs", "participants"
  add_foreign_key "training_programs", "sections"
  add_foreign_key "training_programs", "trainers"
  add_foreign_key "users", "sections"
end
