require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "test_user_#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :participant,
      first_name: "Test",
      last_name: "User",
      active: true
    )
  end

  test "active_for_authentication? requires active: true and deleted_at: nil" do
    assert @user.active_for_authentication?

    # Inactive user cannot authenticate
    @user.update!(active: false)
    assert_not @user.active_for_authentication?

    # Soft deleted user cannot authenticate
    @user.update!(active: true, deleted_at: Time.current)
    assert_not @user.active_for_authentication?
    assert @user.deleted?

    # Kept and deleted scopes
    assert_includes User.deleted, @user
    assert_not_includes User.kept, @user

    @user.update!(deleted_at: nil)
    assert @user.active_for_authentication?
    assert_not @user.deleted?
    assert_includes User.kept, @user
    assert_not_includes User.deleted, @user
  end
end
