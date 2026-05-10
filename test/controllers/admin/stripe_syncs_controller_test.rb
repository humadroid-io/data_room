require "test_helper"

class Admin::StripeSyncsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "redirects with alert when API key is missing" do
    StripeConfig.stubs(:configured?).returns(false)
    StripeSyncJob.expects(:perform_now).never

    post admin_stripe_syncs_path
    assert_redirected_to admin_root_path
    assert_match(/API key/i, flash[:alert])
  end

  test "runs the sync job and shows the summary" do
    StripeConfig.stubs(:configured?).returns(true)
    StripeSyncJob.expects(:perform_now).returns(customers: 3, subscriptions: 5)

    post admin_stripe_syncs_path
    assert_redirected_to admin_root_path
    assert_match(/3 customers/, flash[:notice])
    assert_match(/5 subscriptions/, flash[:notice])
  end

  test "surfaces Stripe authentication errors" do
    StripeConfig.stubs(:configured?).returns(true)
    StripeSyncJob.stubs(:perform_now).raises(Stripe::AuthenticationError.new("bad key"))

    post admin_stripe_syncs_path
    assert_redirected_to admin_root_path
    assert_match(/rejected/i, flash[:alert])
  end

  test "requires admin sign-in" do
    delete admin_logout_path
    post admin_stripe_syncs_path
    assert_redirected_to admin_login_path
  end
end
