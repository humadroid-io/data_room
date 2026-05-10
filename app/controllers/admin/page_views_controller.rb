class Admin::PageViewsController < Admin::BaseController
  def index
    @views = PageView.includes(:investor, :page).order(viewed_at: :desc).limit(200)
    @per_investor = PageView.joins(:investor).group("investors.name").count
    @per_page     = PageView.joins(:page).group("pages.path").count.sort_by { |_, v| -v }.first(20)
  end
end
