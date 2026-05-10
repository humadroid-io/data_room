require "test_helper"

class UserTest < ActiveSupport::TestCase
  subject { build(:user) }

  should have_secure_password
  should validate_presence_of(:name)
  should validate_presence_of(:email)
  should validate_uniqueness_of(:email).case_insensitive
  should define_enum_for(:role).with_values(admin: 0, viewer: 1)

  test "normalizes email to lowercase and stripped" do
    user = create(:user, email: "  Foo@BAR.COM  ")
    assert_equal "foo@bar.com", user.email
  end

  test "authenticate returns user on correct password" do
    user = create(:user, password: "secret123")
    assert user.authenticate("secret123")
    assert_not user.authenticate("wrong")
  end
end
