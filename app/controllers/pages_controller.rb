class PagesController < ApplicationController
  layout "investor"

  before_action :require_viewer

  def show
    requested = normalize_path(params[:path])

    @page = page_scope.find_by(path: requested) || follow_redirect(requested)

    raise ActiveRecord::RecordNotFound unless @page

    if investor_signed_in? && !@page.visible_to?(current_investor)
      raise ActionController::RoutingError, "Forbidden"
    end

    track_view if investor_signed_in?

    @breadcrumbs = build_breadcrumbs(@page)
    @sidebar     = sidebar_tree
  end

  private

  def page_scope
    viewing_as_admin? ? Page.all : Page.live
  end

  def normalize_path(raw)
    cleaned = "/#{raw}".gsub(%r{/+}, "/").sub(%r{/\z}, "")
    cleaned.presence || "/"
  end

  def follow_redirect(old_path)
    PageRedirect.find_by(old_path: old_path)&.page
  end

  def track_view
    PageView.create!(
      investor:   current_investor,
      page:       @page,
      viewed_at:  Time.current,
      ip_address: request.remote_ip
    )
  end

  def build_breadcrumbs(page)
    crumbs = []
    node = page
    while node
      crumbs.unshift(node)
      node = node.parent
    end
    crumbs
  end

  def sidebar_tree
    scope = viewing_as_admin? ? Page.all : Page.live
    scope.where(parent_id: nil).where.not(slug: "").order(:sort_order, :title)
  end
end
