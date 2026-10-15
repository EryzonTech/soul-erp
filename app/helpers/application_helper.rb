module ApplicationHelper
  include Pagy::Frontend
  def active_link?(controller_name)
    case controller_name
    when "dashboard"
      controller.controller_name == "dashboard" ||
      (controller.controller_name == "admin" && controller.action_name == "dashboard")
    when "sections"
      controller.controller_name == "sections"
    when "trainers"
      controller.controller_name == "trainers"
    when "participants"
      controller.controller_name == "participants"
    when "questions"
      controller.controller_name == "questions"
    when "training_programs"
      controller.controller_name == "training_programs"
    when "attendances"
      controller.controller_name == "attendances"
    when "institutes"
      controller.controller_name == "institutes"
    when "users"
      controller.controller_name == "users"
    when "registration_settings"
      controller.controller_name == "registration_settings"
    when "assignments"
      controller.controller_name == "assignments"
    when "responses"
      controller.controller_name == "responses"
    when "profile"
      controller.controller_name == "profile"
    when "question_categories", "category_questions", "question_bundles"
      controller.controller_name.in?(%w[question_categories category_questions question_bundles])
    when "question_imports", "question_category_imports"
      controller.controller_name.in?(%w[question_imports question_category_imports])
    else
      false
    end
  end

  def bootstrap_class_for_flash(flash_type)
    case flash_type.to_sym
    when :success
      "success"
    when :error
      "danger"
    when :alert
      "warning"
    when :notice
      "info"
    else
      flash_type.to_s
    end
  end

  def format_import_log_item(log)
    level = log["level"] || "info"
    time = log["time"] || ""
    message = log["message"] || ""

    if level == "success" && (m = message.match(/^Row\s+(\d+):\s+Created question\s+'([^']+)'\s*\(([^)]+)\)(.*)$/i))
      row_num = m[1]
      title = m[2]
      meta = m[3]
      extra = (m[4] || "").strip
      meta_parts = meta.split(",").map(&:strip)
      q_type = meta_parts[0] || "Question"
      day_range = meta_parts[1]

      tag.div(class: "timeline-step") do
        concat tag.div(tag.i(class: "bi bi-check-lg fs-6"), class: "timeline-node bg-success-subtle text-success border border-success border-opacity-25")
        concat tag.div(class: "timeline-content-card") {
          concat tag.div(class: "d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1.5") {
            concat tag.div(class: "d-flex align-items-center gap-2") {
              concat tag.span("Question Created", class: "badge bg-success-subtle text-success border border-success-subtle rounded-pill px-2.5 py-0.5 small fw-semibold")
              concat tag.span("Row #{row_num}", class: "fw-bold text-dark small")
            }
            concat tag.span(tag.i(class: "bi bi-clock me-1") + time, class: "text-muted small", style: "font-size: 0.75rem;")
          }
          concat tag.div(title, class: "text-dark fw-semibold mb-1.5 small text-truncate", title: title)
          concat tag.div(class: "d-flex align-items-center flex-wrap gap-1.5") {
            concat tag.span(tag.i(class: "bi bi-tag me-1 text-primary") + q_type, class: "badge bg-light text-secondary border rounded-pill px-2 py-0.5 small", style: "font-size: 0.72rem;")
            concat tag.span(tag.i(class: "bi bi-calendar3 me-1 text-info") + day_range, class: "badge bg-light text-secondary border rounded-pill px-2 py-0.5 small", style: "font-size: 0.72rem;") if day_range.present?
            concat tag.span(tag.i(class: "bi bi-list-check me-1 text-success") + extra.sub(/\.\z/, ""), class: "badge bg-light text-secondary border rounded-pill px-2 py-0.5 small", style: "font-size: 0.72rem;") if extra.present?
          }
        }
      end
    elsif level == "success"
      tag.div(class: "timeline-step") do
        concat tag.div(tag.i(class: "bi bi-check-circle-fill fs-6"), class: "timeline-node bg-success-subtle text-success border border-success border-opacity-25")
        concat tag.div(class: "timeline-content-card") {
          concat tag.div(class: "d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1") {
            concat tag.span("Success", class: "badge bg-success-subtle text-success border border-success-subtle rounded-pill px-2.5 py-0.5 small fw-semibold")
            concat tag.span(tag.i(class: "bi bi-clock me-1") + time, class: "text-muted small", style: "font-size: 0.75rem;")
          }
          concat tag.div(message, class: "text-dark small")
        }
      end
    elsif level == "error"
      tag.div(class: "timeline-step") do
        concat tag.div(tag.i(class: "bi bi-x-circle-fill fs-6"), class: "timeline-node bg-danger-subtle text-danger border border-danger border-opacity-25")
        concat tag.div(class: "timeline-content-card border-danger-subtle bg-danger-subtle bg-opacity-10") {
          concat tag.div(class: "d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1") {
            concat tag.span("Validation Error", class: "badge bg-danger-subtle text-danger border border-danger-subtle rounded-pill px-2.5 py-0.5 small fw-semibold")
            concat tag.span(tag.i(class: "bi bi-clock me-1") + time, class: "text-muted small", style: "font-size: 0.75rem;")
          }
          concat tag.div(message, class: "text-danger fw-medium small")
        }
      end
    elsif level == "warn"
      tag.div(class: "timeline-step") do
        concat tag.div(tag.i(class: "bi bi-exclamation-triangle-fill fs-6"), class: "timeline-node bg-warning-subtle text-warning-emphasis border border-warning border-opacity-25")
        concat tag.div(class: "timeline-content-card border-warning-subtle bg-warning-subtle bg-opacity-10") {
          concat tag.div(class: "d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1") {
            concat tag.span("Warning", class: "badge bg-warning-subtle text-warning-emphasis border border-warning-subtle rounded-pill px-2.5 py-0.5 small fw-semibold")
            concat tag.span(tag.i(class: "bi bi-clock me-1") + time, class: "text-muted small", style: "font-size: 0.75rem;")
          }
          concat tag.div(message, class: "text-dark small")
        }
      end
    else
      tag.div(class: "timeline-step") do
        concat tag.div(tag.i(class: "bi bi-info-circle-fill fs-6"), class: "timeline-node bg-primary-subtle text-primary border border-primary border-opacity-25")
        concat tag.div(class: "timeline-content-card") {
          concat tag.div(class: "d-flex align-items-center justify-content-between flex-wrap gap-2 mb-1") {
            concat tag.span("System Step", class: "badge bg-primary-subtle text-primary border border-primary-subtle rounded-pill px-2.5 py-0.5 small fw-semibold")
            concat tag.span(tag.i(class: "bi bi-clock me-1") + time, class: "text-muted small", style: "font-size: 0.75rem;")
          }
          concat tag.div(message, class: "text-dark small")
        }
      end
    end
  end
end
