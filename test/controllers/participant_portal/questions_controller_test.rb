require "test_helper"

module ParticipantPortal
  class QuestionsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @user = users(:two)
      @participant = participants(:two)
      @institute = institutes(:two)
      sign_in @user

      @question = @participant.custom_questions.create!(
        institute: @institute,
        title: "How many hours did you study?",
        question_type: :short_answer,
        required: true,
        active: true
      )
    end

    test "should get index" do
      get participant_portal_questions_url
      assert_response :success
      assert_select "h4", text: /My Custom Questions/
      assert_select "td", text: /How many hours did you study\?/
    end

    test "should get new" do
      get new_participant_portal_question_url
      assert_response :success
      assert_select "form"
    end

    test "should create custom question for participant" do
      assert_difference -> { @participant.custom_questions.count }, 1 do
        post participant_portal_questions_url, params: {
          question: {
            title: "Did you meditate today?",
            question_type: "yes_or_no",
            required: false,
            options_attributes: [
              { text: "Yes", value: "Yes" },
              { text: "No", value: "No" }
            ]
          }
        }
      end

      assert_redirected_to participant_portal_questions_url
      created_q = @participant.custom_questions.order(created_at: :desc).first
      assert_equal "Did you meditate today?", created_q.title
      assert_equal "yes_or_no", created_q.question_type
      assert_equal @participant.id, created_q.participant_id
      assert_equal @institute.id, created_q.institute_id
    end

    test "should create custom question from web form with empty options parameters" do
      assert_difference -> { @participant.custom_questions.count }, 1 do
        post participant_portal_questions_url, params: {
          question: {
            title: "Short Answer Daily Question",
            question_type: "short_answer",
            required: false,
            options_attributes: {
              "0" => { "text" => "", "value" => "" },
              "1" => { "text" => "", "value" => "" }
            }
          }
        }
      end

      assert_redirected_to participant_portal_questions_url
      created_q = @participant.custom_questions.order(created_at: :desc).first
      assert_equal "Short Answer Daily Question", created_q.title
      assert_equal "short_answer", created_q.question_type
      assert_equal 0, created_q.options.count
    end

    test "should create choice question with options from web form" do
      assert_difference -> { @participant.custom_questions.count }, 1 do
        post participant_portal_questions_url, params: {
          question: {
            title: "Morning Routine Checklist",
            question_type: "checkboxes",
            required: true,
            options_attributes: {
              "0" => { "text" => "Drank water", "value" => "" },
              "1" => { "text" => "Exercised", "value" => "" }
            }
          }
        }
      end

      assert_redirected_to participant_portal_questions_url
      created_q = @participant.custom_questions.order(created_at: :desc).first
      assert_equal "Morning Routine Checklist", created_q.title
      assert_equal "checkboxes", created_q.question_type
      assert_equal 2, created_q.options.count
    end

    test "should create custom question via JSON for inline creation in assignment form" do
      assert_difference -> { @participant.custom_questions.count }, 1 do
        post participant_portal_questions_url, as: :json, params: {
          question: {
            title: "Quick Inline Question",
            question_type: "short_answer",
            required: false
          }
        }
      end

      assert_response :success
      json = JSON.parse(response.body)
      assert_equal "success", json["status"]
      assert_equal "Quick Inline Question", json["question"]["title"]
    end

    test "should get show" do
      get participant_portal_question_url(@question)
      assert_response :success
      assert_select "h4", text: @question.title
    end

    test "should get edit" do
      get edit_participant_portal_question_url(@question)
      assert_response :success
      assert_select "form"
    end

    test "should update custom question" do
      patch participant_portal_question_url(@question), params: {
        question: {
          title: "Updated Study Hours Question",
          required: false
        }
      }

      assert_redirected_to participant_portal_questions_url
      @question.reload
      assert_equal "Updated Study Hours Question", @question.title
      assert_not @question.required
    end

    test "should destroy custom question" do
      assert_difference -> { @participant.custom_questions.count }, -1 do
        delete participant_portal_question_url(@question)
      end

      assert_redirected_to participant_portal_questions_url
    end

    test "cannot view or edit another participant's custom question" do
      other_participant = participants(:one)
      other_q = other_participant.custom_questions.create!(
        institute: institutes(:one),
        title: "Other Participant's Private Question",
        question_type: :short_answer
      )

      get participant_portal_question_url(other_q)
      assert_redirected_to participant_portal_questions_url
      assert_equal "Question not found or you don't have permission to access it.", flash[:alert]

      patch participant_portal_question_url(other_q), params: {
        question: { title: "Hacked Title" }
      }
      assert_redirected_to participant_portal_questions_url
      other_q.reload
      assert_equal "Other Participant's Private Question", other_q.title
    end
  end
end
