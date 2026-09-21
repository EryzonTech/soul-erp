require "test_helper"

module ParticipantPortal
  class AssignmentsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @user = users(:two)
      @participant = participants(:two)
      @institute = institutes(:two)
      sign_in @user

      @q1 = @participant.custom_questions.create!(
        institute: @institute,
        title: "Daily Goal Met?",
        question_type: :short_answer,
        required: true,
        active: true
      )

      @custom_assignment = @institute.assignments.create!(
        title: "My Self-Study Plan",
        description: "Self-driven routine",
        start_date: Date.current,
        end_date: Date.current + 14.days,
        assignment_type: "individual",
        participant: @participant,
        active: true
      )
      @custom_assignment.assignment_participants.create!(participant: @participant)
      @custom_assignment.assignment_questions.create!(question: @q1, order_number: 1)
    end

    test "should get index with custom assignment" do
      get participant_portal_assignments_url
      assert_response :success
      assert_select "h4", text: /My Assignments/
      assert_select ".assignment-title", text: /My Self-Study Plan/
      assert_select ".badge", text: /Custom/
    end

    test "should get new custom assignment form" do
      get new_participant_portal_assignment_url
      assert_response :success
      assert_select "h4", text: /Create Custom Assignment/
      assert_select "input[name='assignment[title]']"
    end

    test "should create custom assignment" do
      q2 = @participant.custom_questions.create!(
        institute: @institute,
        title: "Workout Duration?",
        question_type: :number,
        required: false
      )

      assert_difference -> { @participant.custom_assignments.count }, 1 do
        post participant_portal_assignments_url, params: {
          assignment: {
            title: "Fitness & Wellness",
            description: "Daily tracking",
            start_date: Date.current.to_s,
            end_date: (Date.current + 7.days).to_s,
            active: true,
            question_ids: [ q2.id ]
          }
        }
      end

      assert_response :see_other
      assert_redirected_to participant_portal_assignments_url
      created = @participant.custom_assignments.order(created_at: :desc).first
      assert_equal "Fitness & Wellness", created.title
      assert_equal "individual", created.assignment_type
      assert_equal @participant.id, created.participant_id
      assert_includes created.participants, @participant
      assert_includes created.questions, q2
    end

    test "cannot create assignment with institute questions or non-owned questions" do
      institute_q = questions(:required_question) # has participant_id: nil

      assert_no_difference -> { @participant.custom_assignments.count } do
        post participant_portal_assignments_url, params: {
          assignment: {
            title: "Invalid Assignment with Institute Q",
            start_date: Date.current.to_s,
            end_date: (Date.current + 7.days).to_s,
            question_ids: [ institute_q.id ]
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select ".alert", text: /Please select at least one of your custom questions/
    end

    test "should get edit for own custom assignment" do
      get edit_participant_portal_assignment_url(@custom_assignment)
      assert_response :success
      assert_select "h4", text: /Edit Custom Assignment/
    end

    test "should update own custom assignment" do
      patch participant_portal_assignment_url(@custom_assignment), params: {
        assignment: {
          title: "Updated Self-Study Plan",
          description: "Updated description",
          start_date: @custom_assignment.start_date.to_date.to_s,
          end_date: @custom_assignment.end_date.to_date.to_s,
          question_ids: [ @q1.id ]
        }
      }

      assert_redirected_to participant_portal_assignments_url
      @custom_assignment.reload
      assert_equal "Updated Self-Study Plan", @custom_assignment.title
    end

    test "should destroy own custom assignment" do
      assert_difference -> { @participant.custom_assignments.count }, -1 do
        delete participant_portal_assignment_url(@custom_assignment)
      end

      assert_redirected_to participant_portal_assignments_url
    end

    test "cannot edit or delete an institute assignment created by admin" do
      admin_assignment = @institute.assignments.create!(
        title: "Institute Mandatory Assignment",
        start_date: Date.current,
        end_date: Date.current + 30.days,
        assignment_type: "individual",
        participant_id: nil,
        active: true
      )
      admin_assignment.assignment_participants.create!(participant: @participant)
      admin_assignment.assignment_questions.create!(question: @q1, order_number: 1)

      get edit_participant_portal_assignment_url(admin_assignment)
      assert_redirected_to participant_portal_assignments_url
      assert_equal "You can only edit or delete assignments you created.", flash[:alert]

      delete participant_portal_assignment_url(admin_assignment)
      assert_redirected_to participant_portal_assignments_url
      assert_equal "You can only edit or delete assignments you created.", flash[:alert]
      assert Assignment.exists?(admin_assignment.id)
    end

    test "should take and submit custom assignment" do
      get take_assignment_participant_portal_assignment_url(@custom_assignment, date: Date.current)
      assert_response :success
      assert_select "h5", text: @custom_assignment.title
      assert_select "label", text: /Daily Goal Met\?/

      assert_difference -> { @participant.assignment_responses.count }, 1 do
        post submit_participant_portal_assignment_url(@custom_assignment, date: Date.current), params: {
          responses: {
            @q1.id.to_s => { answer: "Yes, completed 2 hours!" }
          }
        }
      end

      assert_redirected_to participant_portal_root_path(date: Date.current)
      assert @custom_assignment.answered_by_on_date?(@participant, Date.current)
    end
  end
end
