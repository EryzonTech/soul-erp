# frozen_string_literal: true

module ParticipantPortal
  class AnalyticsController < ParticipantPortal::BaseController
    def index
      @participant = current_participant
      @analytics = ParticipantPortal::AnalyticsQuery.new(
        participant: current_participant,
        institute: current_institute,
        params: query_params
      ).call

      # Expose key variables for view rendering
      @selected_range = @analytics[:selected_range]
      @start_date = @analytics[:start_date]
      @end_date = @analytics[:end_date]
      @selected_assignment_id = @analytics[:selected_assignment_id]
      @available_assignments = @analytics[:available_assignments]

      @total_questions_answered = @analytics[:total_questions_answered]
      @total_submitted_days = @analytics[:total_submitted_days]
      @active_streak = @analytics[:active_streak]
      @longest_streak = @analytics[:longest_streak]
      @avg_rating = @analytics[:avg_rating]
      @rating_count = @analytics[:rating_count]
      @overall_completion_rate = @analytics[:overall_completion_rate]
      @overall_adherence_rate = @analytics[:overall_adherence_rate]

      @trend_labels = @analytics[:trend_labels]
      @trend_data = @analytics[:trend_data]
      @category_labels = @analytics[:category_labels]
      @category_data = @analytics[:category_data]
      @dow_labels = @analytics[:dow_labels]
      @dow_data = @analytics[:dow_data]
      @tod_labels = @analytics[:tod_labels]
      @tod_data = @analytics[:tod_data]
      @type_labels = @analytics[:type_labels]
      @type_data = @analytics[:type_data]
      @rating_trend_labels = @analytics[:rating_trend_labels]
      @rating_trend_data = @analytics[:rating_trend_data]

      @heatmap_days = @analytics[:heatmap_days]
      @assignment_scorecards = @analytics[:assignment_scorecards]

      @most_active_date = @analytics[:most_active_date]
      @most_active_count = @analytics[:most_active_count]
      @top_category_name = @analytics[:top_category_name]
      @top_category_count = @analytics[:top_category_count]

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    private

    def query_params
      params.permit(:range, :start_date, :end_date, :assignment_id)
    end
  end
end
