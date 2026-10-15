# frozen_string_literal: true

module ParticipantPortal
  class ResponsesController < ParticipantPortal::BaseController
    helper ParticipantPortal::ResponsesHelper

    def index
      query_parameters = query_params
      if query_parameters[:range].blank? && query_parameters[:start_date].blank? && query_parameters[:end_date].blank?
        query_parameters[:range] = "today"
      end

      @query = ParticipantPortal::ResponsesQuery.new(
        participant: current_participant,
        institute: current_institute,
        params: query_parameters
      )

      @pagy, @submission_logs = pagy(@query.call, items: 10)
      @stats = @query.stats
      @available_assignments = @query.available_assignments

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def show
      @submission_log = current_participant.assignment_response_logs
                                           .includes(assignment: :question_category)
                                           .find(params[:id])
      @assignment = @submission_log.assignment
      @responses = if @submission_log.assignment_response_ids.present?
                     AssignmentResponse.where(id: @submission_log.assignment_response_ids)
                                       .includes(question: [ :options, :question_category ])
                                       .order("questions.position ASC, questions.id ASC")
      else
                     current_participant.assignment_responses
                                        .where(assignment_id: @assignment.id, response_date: @submission_log.response_date.to_date)
                                        .includes(question: [ :options, :question_category ])
                                        .order("questions.position ASC, questions.id ASC")
      end

      @grouped_responses = @responses.group_by { |r| r.question.question_category&.name || "General Questions" }
    end

    private

    def query_params
      params.permit(:assignment_id, :range, :start_date, :end_date, :query, :page)
    end
  end
end
