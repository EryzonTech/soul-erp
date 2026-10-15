# frozen_string_literal: true

module ParticipantPortal
  class ResponsesQuery
    attr_reader :participant, :institute, :params

    def initialize(participant:, institute:, params: {})
      @participant = participant
      @institute = institute
      @params = params
    end

    def call
      scope = base_scope
      scope = filter_by_assignment(scope)
      scope = filter_by_date(scope)
      scope = filter_by_query(scope) if params[:query].present?
      scope.order(response_date: :desc, created_at: :desc)
    end

    def stats
      total_answers = AssignmentResponse.where(participant: participant).count
      date_scope = base_scope.pluck(:response_date).compact
      date_set = date_scope.map(&:to_date).to_set
      total_days = date_set.size
      streak = calculate_streak(date_set)
      assignments_count = base_scope.select(:assignment_id).distinct.count

      {
        total_answers: total_answers,
        total_days: total_days,
        streak: streak,
        assignments_count: assignments_count
      }
    end

    def available_assignments
      Assignment.where(id: base_scope.select(:assignment_id).distinct)
                .order(:title)
    end

    private

    def base_scope
      @base_scope ||= AssignmentResponseLog.where(participant: participant, institute: institute)
                                          .includes(assignment: :question_category)
    end

    def filter_by_assignment(scope)
      return scope if params[:assignment_id].blank?

      scope.where(assignment_id: params[:assignment_id])
    end

    def filter_by_date(scope)
      if params[:start_date].present? || params[:end_date].present? || params[:range] == "custom"
        s_date = parse_date(params[:start_date])
        e_date = parse_date(params[:end_date])
        if s_date.present? && e_date.present?
          min_d = [ s_date, e_date ].min
          max_d = [ s_date, e_date ].max
          scope.where(response_date: min_d.beginning_of_day..max_d.end_of_day)
        elsif s_date.present?
          scope.where("response_date >= ?", s_date.beginning_of_day)
        elsif e_date.present?
          scope.where("response_date <= ?", e_date.end_of_day)
        else
          scope
        end
      else
        range = params[:range].presence || "today"
        case range
        when "today"
          scope.where(response_date: Date.current.beginning_of_day..Date.current.end_of_day)
        when "7"
          scope.where("response_date >= ?", 7.days.ago.beginning_of_day)
        when "30"
          scope.where("response_date >= ?", 30.days.ago.beginning_of_day)
        when "90"
          scope.where("response_date >= ?", 90.days.ago.beginning_of_day)
        when "all"
          scope
        else
          scope.where(response_date: Date.current.beginning_of_day..Date.current.end_of_day)
        end
      end
    end

    def filter_by_query(scope)
      q = "%#{params[:query].strip}%"

      matching_asg_ids = Assignment.where(id: base_scope.select(:assignment_id))
                                   .where("title ILIKE ?", q)
                                   .pluck(:id)

      matching_pairs = AssignmentResponse.joins(:question)
                                        .where(participant: participant)
                                        .where("assignment_responses.answer ILIKE :q OR questions.title ILIKE :q", q: q)
                                        .pluck(:assignment_id, :response_date)

      conditions = []
      conditions << "assignment_id IN (#{matching_asg_ids.join(',')})" if matching_asg_ids.any?

      matching_pairs.each do |asg_id, r_date|
        d = r_date.to_date
        conditions << "(assignment_id = #{asg_id.to_i} AND response_date >= '#{d.beginning_of_day.to_fs(:db)}' AND response_date <= '#{d.end_of_day.to_fs(:db)}')"
      end

      if conditions.any?
        scope.where(conditions.join(" OR "))
      else
        scope.none
      end
    end

    def calculate_streak(submitted_dates)
      return 0 if submitted_dates.empty?

      streak = 0
      check_date = Date.current

      if submitted_dates.include?(check_date)
        while submitted_dates.include?(check_date)
          streak += 1
          check_date -= 1.day
        end
      elsif submitted_dates.include?(check_date - 1.day)
        check_date -= 1.day
        while submitted_dates.include?(check_date)
          streak += 1
          check_date -= 1.day
        end
      end

      streak
    end

    def parse_date(date_str)
      return nil if date_str.blank?

      Date.parse(date_str.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
