require "test_helper"

class Admin::PagesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "requires admin sign-in" do
    delete admin_logout_path
    get admin_pages_path
    assert_redirected_to admin_login_path
  end

  test "GET index" do
    create(:section_page, slug: "p")
    get admin_pages_path
    assert_response :success
  end

  test "GET new" do
    get new_admin_page_path
    assert_response :success
  end

  test "POST create persists a page" do
    assert_difference -> { Page.count }, 1 do
      post admin_pages_path, params: {
        page: { title: "About", slug: "about", visibility: "public" }
      }
    end
    assert_redirected_to admin_page_path(Page.last)
  end

  test "POST create with private visibility + allowed_investor_ids fills the allowlist" do
    investor = create(:investor)

    assert_difference -> { PageAccess.count }, 1 do
      post admin_pages_path, params: {
        page: { title: "Sec", slug: "sec", visibility: "private",
                allowed_investor_ids: [ investor.id ] }
      }
    end
    assert Page.last.page_accesses.exists?(investor_id: investor.id)
  end

  test "POST create with public visibility ignores allowed_investor_ids" do
    investor = create(:investor)

    assert_no_difference -> { PageAccess.count } do
      post admin_pages_path, params: {
        page: { title: "Pub", slug: "pub", visibility: "public",
                allowed_investor_ids: [ investor.id ] }
      }
    end
  end

  test "PATCH update changes title" do
    page = create(:section_page, slug: "x")
    patch admin_page_path(page), params: { page: { title: "New title" } }
    assert_redirected_to admin_page_path(page)
    assert_equal "New title", page.reload.title
  end

  test "PATCH update syncs the allowlist on a private page" do
    page     = create(:private_page, slug: "x")
    investor = create(:investor)

    patch admin_page_path(page), params: {
      page: { title: page.title, visibility: "private",
              allowed_investor_ids: [ investor.id ] }
    }
    assert page.page_accesses.exists?(investor_id: investor.id)

    patch admin_page_path(page), params: {
      page: { title: page.title, visibility: "private", allowed_investor_ids: [] }
    }
    assert_not page.page_accesses.exists?(investor_id: investor.id)
  end

  test "PATCH update wipes allowlist when changing from private to public" do
    page     = create(:private_page, slug: "x")
    investor = create(:investor)
    create(:page_access, page: page, investor: investor)
    assert page.page_accesses.exists?

    patch admin_page_path(page), params: {
      page: { visibility: "public" }
    }
    assert_not page.reload.page_accesses.exists?
  end

  test "DELETE destroys page" do
    page = create(:section_page, slug: "del")
    assert_difference -> { Page.count }, -1 do
      delete admin_page_path(page)
    end
  end
end
