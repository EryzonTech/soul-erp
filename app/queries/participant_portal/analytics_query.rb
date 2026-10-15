# frozen_string_literal: true

module ParticipantPortal
  class AnalyticsQuery
    attr_reader :participant, :institute, :params

    def initialize(participant:, institute:, params: {})
      @participant = participant
      @institute = institute
      @params = params
    end

    def call
      resolve_date_boundaries
      fetch_data
      build_result
    end

    private

    def resolve_date_boundaries
      @selected_range = params[:range].presence || "30"
      @selected_assignment_id = params[:assignment_id].presence

      if @selected_range == "custom" && (params[:start_date].present? || params[:end_date].present?)
        @start_date = parse_date(params[:start_date]) || 30.days.ago.to_date
        @end_date = parse_date(params[:end_date]) || Date.current
        if @start_date > @end_date
          @start_date, @end_date = @end_date, @start_date
        end
      else
        @end_date = Date.current
        @start_date = case @selected_range
        when "7" then 7.days.ago.to_date
        when "30" then 30.days.ago.to_date
        when "90" then 90.days.ago.to_date
        when "all" then nil
        else 30.days.ago.to_date
        end
      end
    end

    def fetch_data
      # 1. Assignments available to participant
      @available_assignments = Assignment.for_participant(participant).order(start_date: :desc).to_a
      if @selected_assignment_id.present?
        @scoped_assignment_ids = @available_assignments.select { |a| a.id.to_s == @selected_assignment_id.to_s }.map(&:id)
      else
        @scoped_assignment_ids = @available_assignments.map(&:id)
      end

      # 2. Assignment Response Logs (Single-Pass Extraction)
      base_logs_scope = AssignmentResponseLog.where(participant: participant, institute: institute)
      base_logs_scope = base_logs_scope.where(assignment_id: @scoped_assignment_ids) if @selected_assignment_id.present?

      # Extract all logs in a single query: [assignment_id, response_date (datetime), created_at]
      all_logs_raw = base_logs_scope.pluck(:assignment_id, :response_date, :created_at)

      # Build global calendar dates set for streak calculation
      @all_submitted_dates = all_logs_raw.filter_map { |r| r[1]&.to_date }.to_set

      # Filter logs by the selected date range
      @filtered_logs = if @start_date.present?
                         all_logs_raw.select { |r| r[1].present? && r[1].to_date >= @start_date && r[1].to_date <= @end_date }
      else
                         all_logs_raw.select { |r| r[1].present? && r[1].to_date <= @end_date }
      end

      # Map assignment_id => Set of distinct calendar dates submitted
      @assignment_submitted_dates_map = Hash.new { |h, k| h[k] = Set.new }
      all_logs_raw.each do |asg_id, resp_dt, _|
        @assignment_submitted_dates_map[asg_id].add(resp_dt.to_date) if resp_dt.present?
      end

      # 3. Assignment Responses
      base_responses = AssignmentResponse.where(participant: participant)
      base_responses = base_responses.where(assignment_id: @scoped_assignment_ids) if @selected_assignment_id.present?

      if @start_date.present?
        base_responses = base_responses.where(response_date: @start_date..@end_date)
      else
        base_responses = base_responses.where("response_date <= ?", @end_date)
      end

      @total_questions_answered = base_responses.count

      # Daily response counts for trend chart
      trend_days_limit = case @selected_range
      when "7" then 7
      when "90" then 90
      when "all" then 30
      else 30
      end
      trend_start = trend_days_limit.days.ago.to_date
      @daily_counts = base_responses.where("response_date >= ?", trend_start)
                                    .group(:response_date)
                                    .count

      # Question category breakdown (actual categories with fallback to 'General')
      @category_counts = base_responses.joins(:question)
                                       .left_outer_joins(question: :question_category)
                                       .group("COALESCE(question_categories.name, 'General')")
                                       .count

      # Question type distribution
      @type_counts = base_responses.joins(:question)
                                   .group("questions.question_type")
                                   .count

      # Star ratings (Strictly question_type == 7 / rating)
      rating_type_int = Question.question_types["rating"]
      @rating_records = base_responses.joins(:question)
                                      .where(questions: { question_type: rating_type_int })
                                      .pluck(:response_date, :answer)
    end

    def build_result
      # 1. Streaks
      streaks = calculate_streaks(@all_submitted_dates)
      active_streak = streaks[:current]
      longest_streak = streaks[:longest]

      # 2. Total Submitted Days (Normalized Calendar Dates)
      filtered_calendar_dates = @filtered_logs.filter_map { |r| r[1]&.to_date }.uniq
      total_submitted_days = filtered_calendar_dates.size

      # 3. Star Ratings & Progression
      rating_data = process_ratings(@rating_records)

      # 4. Daily Activity Trend
      trend_chart_data = build_trend_chart_data(@daily_counts)

      # 5. Day of Week Patterns
      dow_chart_data = build_dow_chart_data(@filtered_logs)

      # 6. Time of Day Rhythm
      tod_chart_data = build_tod_chart_data(@filtered_logs)

      # 7. Category Breakdown
      cat_chart_data = build_category_chart_data(@category_counts)

      # 8. Question Type Breakdown
      type_chart_data = build_type_chart_data(@type_counts)

      # 9. Assignment Performance Scorecards & Overall Rates
      scorecard_result = build_scorecards(@available_assignments, @assignment_submitted_dates_map)

      # 10. Habit Heatmap Data (Last 90 days grid)
      heatmap_data = build_heatmap_data(@all_submitted_dates, @daily_counts)

      # 11. Personal Bests
      most_active_day = @daily_counts.max_by { |_k, v| v }

      {
        selected_range: @selected_range,
        start_date: @start_date,
        end_date: @end_date,
        selected_assignment_id: @selected_assignment_id,
        available_assignments: @available_assignments,

        # Key KPIs
        total_questions_answered: @total_questions_answered,
        total_submitted_days: total_submitted_days,
        active_streak: active_streak,
        longest_streak: longest_streak,
        avg_rating: rating_data[:avg_rating],
        rating_count: rating_data[:count],
        rating_distribution: rating_data[:distribution],
        overall_completion_rate: scorecard_result[:overall_completion_rate],
        overall_adherence_rate: scorecard_result[:overall_adherence_rate],

        # Chart Datasets
        trend_labels: trend_chart_data[:labels],
        trend_data: trend_chart_data[:data],
        category_labels: cat_chart_data[:labels],
        category_data: cat_chart_data[:data],
        dow_labels: dow_chart_data[:labels],
        dow_data: dow_chart_data[:data],
        tod_labels: tod_chart_data[:labels],
        tod_data: tod_chart_data[:data],
        type_labels: type_chart_data[:labels],
        type_data: type_chart_data[:data],
        rating_trend_labels: rating_data[:trend_labels],
        rating_trend_data: rating_data[:trend_data],

        # Heatmap & Scorecards
        heatmap_days: heatmap_data,
        assignment_scorecards: scorecard_result[:scorecards],

        # Highlights & Personal Bests
        most_active_date: most_active_day&.first,
        most_active_count: most_active_day&.last || 0,
        top_category_name: cat_chart_data[:labels].first || "General",
        top_category_count: cat_chart_data[:data].first || 0
      }
    end

    def calculate_streaks(date_set)
      return { current: 0, longest: 0 } if date_set.blank?

      # Current active streak
      current = 0
      check_date = Date.current
      if date_set.include?(check_date)
        while date_set.include?(check_date)
          current += 1
          check_date -= 1.day
        end
      elsif date_set.include?(check_date - 1.day)
        check_date -= 1.day
        while date_set.include?(check_date)
          current += 1
          check_date -= 1.day
        end
      end

      # Longest streak ever
      sorted_dates = date_set.to_a.sort
      longest = 0
      streak = 0
      sorted_dates.each_with_index do |d, idx|
        if idx == 0
          streak = 1
        elsif d == sorted_dates[idx - 1] + 1.day
          streak += 1
        elsif d > sorted_dates[idx - 1] + 1.day
          streak = 1
        end
        longest = [ longest, streak ].max
      end
      longest = [ longest, current ].max

      { current: current, longest: longest }
    end

    def process_ratings(records)
      valid_ratings = []
      by_date = Hash.new { |h, k| h[k] = [] }
      distribution = { 5 => 0, 4 => 0, 3 => 0, 2 => 0, 1 => 0 }

      records.each do |resp_date, answer|
        val = Float(answer) rescue nil
        next unless val && val.between?(1, 5)

        valid_ratings << val
        by_date[resp_date.to_date] << val
        star_key = val.round.clamp(1, 5)
        distribution[star_key] += 1
      end

      avg = valid_ratings.any? ? (valid_ratings.sum / valid_ratings.size.to_f).round(1) : nil

      sorted_dates = by_date.keys.sort
      trend_labels = sorted_dates.map { |d| d.strftime("%b %d") }
      trend_data = sorted_dates.map do |d|
        vals = by_date[d]
        (vals.sum / vals.size.to_f).round(1)
      end

      {
        avg_rating: avg,
        count: valid_ratings.size,
        distribution: distribution,
        trend_labels: trend_labels,
        trend_data: trend_data
      }
    end

    def build_trend_chart_data(daily_counts)
      days_limit = case @selected_range
      when "7" then 7
      when "90" then 30 # For chart readability, cap at 30 days daily interval
      when "all" then 30
      else 14
      end

      date_series = (days_limit.days.ago.to_date..Date.current).to_a
      {
        labels: date_series.map { |d| d.strftime("%b %d") },
        data: date_series.map { |d| daily_counts[d] || 0 }
      }
    end

    def build_dow_chart_data(logs)
      dow_order = %w[Mon Tue Wed Thu Fri Sat Sun]
      dow_counts = Hash.new(0)

      logs.each do |_, resp_dt, _|
        next unless resp_dt.present?

        dow_counts[resp_dt.to_date.strftime("%a")] += 1
      end

      {
        labels: dow_order,
        data: dow_order.map { |day| dow_counts[day] }
      }
    end

    def build_tod_chart_data(logs)
      tod_categories = [
        "Morning (5am-12pm)",
        "Afternoon (12pm-5pm)",
        "Evening (5pm-9pm)",
        "Night (9pm-5am)"
      ]
      counts = Hash.new(0)

      logs.each do |_, _, created_at|
        next unless created_at.present?

        hour = created_at.in_time_zone.hour
        category = case hour
        when 5..11 then "Morning (5am-12pm)"
        when 12..16 then "Afternoon (12pm-5pm)"
        when 17..20 then "Evening (5pm-9pm)"
        else "Night (9pm-5am)"
        end
        counts[category] += 1
      end

      {
        labels: tod_categories,
        data: tod_categories.map { |cat| counts[cat] }
      }
    end

    def build_category_chart_data(category_counts)
      sorted = category_counts.sort_by { |_k, v| -v }
      labels = sorted.map(&:first).presence || [ "No Categories" ]
      data = sorted.map(&:last).presence || [ 0 ]

      { labels: labels, data: data }
    end

    def build_type_chart_data(type_counts)
      labels = type_counts.keys.map do |k|
        Question.question_types.key(k)&.titleize || k.to_s.titleize
      end.presence || [ "No Types" ]
      data = type_counts.values.presence || [ 0 ]

      { labels: labels, data: data }
    end

    def build_scorecards(assignments, submitted_dates_map)
      total_eligible_days_sum = 0
      total_submitted_days_sum = 0
      total_elapsed_days_sum = 0

      scorecards = assignments.map do |assignment|
        start_d = assignment.start_date.to_date
        end_d = assignment.end_date.to_date
        total_days = [ (end_d - start_d).to_i + 1, 1 ].max
        submitted_days = (submitted_dates_map[assignment.id] || Set.new).size

        # Elapsed days up to today
        elapsed_days = if Date.current < start_d
                         0
        elsif Date.current > end_d
                         total_days
        else
                         (Date.current - start_d).to_i + 1
        end

        total_eligible_days_sum += total_days
        total_submitted_days_sum += [ submitted_days, total_days ].min
        total_elapsed_days_sum += elapsed_days

        # Adherence Rate (Pace to date)
        adherence_pct = if elapsed_days.positive?
                          [ ((submitted_days.to_f / elapsed_days) * 100).round(1), 100.0 ].min
        else
                          100.0
        end

        # Overall Completion Rate
        completion_pct = [ ((submitted_days.to_f / total_days) * 100).round(1), 100.0 ].min

        status = if submitted_days >= total_days || (end_d < Date.current && completion_pct >= 90.0)
                   "completed"
        elsif end_d < Date.current
                   "expired"
        elsif adherence_pct >= 80.0
                   "on_track"
        else
                   "needs_attention"
        end

        {
          assignment: assignment,
          total_days: total_days,
          elapsed_days: elapsed_days,
          submitted_days: submitted_days,
          adherence_pct: adherence_pct,
          completion_pct: completion_pct,
          status: status
        }
      end

      overall_completion = total_eligible_days_sum.positive? ? ((total_submitted_days_sum.to_f / total_eligible_days_sum) * 100).round(1) : 0.0
      overall_adherence = total_elapsed_days_sum.positive? ? [ ((total_submitted_days_sum.to_f / total_elapsed_days_sum) * 100).round(1), 100.0 ].min : 100.0

      {
        scorecards: scorecards,
        overall_completion_rate: overall_completion,
        overall_adherence_rate: overall_adherence
      }
    end

    def build_heatmap_data(all_submitted_dates, daily_counts)
      # Last 90 days grid (approx. 13 weeks)
      heatmap_days = []
      90.downto(0) do |days_ago|
        d = days_ago.days.ago.to_date
        count = daily_counts[d] || (all_submitted_dates.include?(d) ? 1 : 0)
        level = case count
        when 0 then 0
        when 1..3 then 1
        when 4..8 then 2
        else 3
        end
        heatmap_days << {
          date: d,
          count: count,
          level: level,
          day_of_week: d.wday
        }
      end
      heatmap_days
    end

    def parse_date(str)
      return nil if str.blank?

      Date.parse(str.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
