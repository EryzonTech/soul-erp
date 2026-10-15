# frozen_string_literal: true

module ParticipantPortal
  module ResponsesHelper
    def render_participant_answer(response)
      return tag.span("No answer recorded", class: "text-muted fst-italic small") if response.blank? || (response.answer.blank? && response.selected_options.blank?)

      question = response.question
      case question.question_type
      when "rating"
        render_rating_answer(response)
      when "checkboxes"
        render_checkbox_answer(response)
      when "multiple_choice", "dropdown", "yes_or_no"
        render_single_choice_answer(response)
      when "date"
        render_date_answer(response)
      when "time"
        render_time_answer(response)
      when "number"
        render_number_answer(response)
      else # short_answer, paragraph
        render_text_answer(response)
      end
    end

    def render_rating_answer(response)
      val = (response.answer.to_i rescue 0)
      stars = (1..5).map do |i|
        if i <= val
          tag.i(class: "bi bi-star-fill text-warning me-1")
        else
          tag.i(class: "bi bi-star text-muted opacity-50 me-1")
        end
      end

      tag.div(class: "d-flex align-items-center gap-2 flex-wrap") do
        concat tag.div(safe_join(stars), class: "d-inline-flex align-items-center")
        concat tag.span("#{val} / 5", class: "badge bg-warning-subtle text-warning-emphasis border border-warning-subtle rounded-pill fw-semibold")
      end
    end

    def render_checkbox_answer(response)
      opts = if response.selected_options.present?
               Array(response.selected_options).reject(&:blank?)
      else
               response.answer.to_s.split(",").map(&:strip).reject(&:blank?)
      end

      return tag.span("No options selected", class: "text-muted fst-italic small") if opts.empty?

      tag.div(class: "d-flex flex-wrap gap-1.5") do
        safe_join(opts.map do |opt|
          tag.span(class: "badge bg-indigo-subtle text-indigo border border-indigo-subtle rounded-pill px-2.5 py-1 small fw-semibold") do
            concat tag.i(class: "bi bi-check2 me-1")
            concat opt
          end
        end)
      end
    end

    def render_single_choice_answer(response)
      ans = response.answer.presence || response.selected_options&.first
      return tag.span("None selected", class: "text-muted fst-italic small") if ans.blank?

      badge_class = case ans.to_s.downcase
      when "yes"
                      "bg-success-subtle text-success border border-success-subtle"
      when "no"
                      "bg-secondary-subtle text-secondary border border-secondary-subtle"
      else
                      "bg-primary-subtle text-primary border border-primary-subtle"
      end

      tag.span(class: "badge #{badge_class} rounded-pill px-3 py-1.5 fw-semibold") do
        concat tag.i(class: "bi bi-check-circle-fill me-1.5")
        concat ans
      end
    end

    def render_date_answer(response)
      formatted = Date.parse(response.answer.to_s).strftime("%b %d, %Y") rescue response.answer
      tag.span(class: "badge bg-info-subtle text-info border border-info-subtle rounded-pill px-3 py-1.5 fw-semibold") do
        concat tag.i(class: "bi bi-calendar-event me-1.5")
        concat formatted
      end
    end

    def render_time_answer(response)
      formatted = Time.parse(response.answer.to_s).strftime("%I:%M %p") rescue response.answer
      tag.span(class: "badge bg-info-subtle text-info border border-info-subtle rounded-pill px-3 py-1.5 fw-semibold") do
        concat tag.i(class: "bi bi-clock me-1.5")
        concat formatted
      end
    end

    def render_number_answer(response)
      tag.span(class: "badge bg-light text-dark border rounded-pill px-3 py-1.5 fw-bold") do
        concat tag.i(class: "bi bi-hash me-1 text-primary")
        concat response.answer
      end
    end

    def render_text_answer(response)
      tag.div(class: "response-text-bubble p-2.5 p-md-3 rounded-3 bg-light border border-light-subtle text-dark small") do
        concat tag.i(class: "bi bi-quote me-1 text-indigo opacity-75")
        concat simple_format(response.answer, class: "d-inline mb-0")
      end
    end

    def question_type_badge(question_type)
      icon, label = case question_type.to_s
      when "rating"          then [ "bi-star-half", "Rating" ]
      when "checkboxes"      then [ "bi-check2-square", "Checkboxes" ]
      when "multiple_choice" then [ "bi-ui-radios", "Multiple Choice" ]
      when "dropdown"        then [ "bi-menu-button-wide", "Dropdown" ]
      when "yes_or_no"       then [ "bi-toggle-on", "Yes / No" ]
      when "date"            then [ "bi-calendar3", "Date" ]
      when "time"            then [ "bi-clock", "Time" ]
      when "number"          then [ "bi-123", "Number" ]
      when "paragraph"       then [ "bi-text-paragraph", "Paragraph" ]
      else                        [ "bi-input-cursor-text", "Short Answer" ]
      end

      tag.span(class: "badge bg-light text-secondary border fw-normal text-capitalize") do
        concat tag.i(class: "bi #{icon} me-1 text-muted")
        concat label
      end
    end

    def relative_submission_date(date)
      return "" if date.blank?

      d = date.to_date
      if d == Date.current
        "Today"
      elsif d == Date.yesterday
        "Yesterday"
      else
        d.strftime("%b %d, %Y")
      end
    end
  end
end
