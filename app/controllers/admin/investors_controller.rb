class Admin::InvestorsController < Admin::BaseController
  before_action :set_investor, only: %i[show edit update destroy regenerate_access_code]

  def index
    @investors  = Investor.order(:name)
    @view_count = PageView.group(:investor_id).count
  end

  def show
    @total_views     = @investor.page_views.count
    @distinct_pages  = @investor.page_views.distinct.count(:page_id)
    @first_view      = @investor.page_views.minimum(:viewed_at)
    @last_view       = @investor.page_views.maximum(:viewed_at)

    @per_page = @investor.page_views
      .joins(:page)
      .group("pages.path", "pages.title", "pages.id")
      .pluck(
        "pages.id",
        "pages.path",
        "pages.title",
        Arel.sql("COUNT(page_views.id) AS views"),
        Arel.sql("MAX(page_views.viewed_at) AS last_seen")
      )
      .map { |id, path, title, views, last_seen|
        { id: id, path: path, title: title, views: views, last_seen: last_seen }
      }
      .sort_by { |row| -row[:views] }

    @recent = @investor.page_views.includes(:page).order(viewed_at: :desc).limit(50)
    @allowed_pages = @investor.page_accesses.includes(:page).map(&:page)
                              .select { |p| p.visibility_private? }
                              .sort_by(&:path)
  end

  def new
    @investor = Investor.new(active: true)
  end

  def edit; end

  def create
    @investor = Investor.new(investor_params)
    if @investor.save
      redirect_to admin_investor_path(@investor), notice: "Investor created. Access code: #{@investor.access_code}"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @investor.update(investor_params)
      redirect_to admin_investor_path(@investor), notice: "Investor updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @investor.destroy
    redirect_to admin_investors_path, notice: "Investor deleted."
  end

  def regenerate_access_code
    @investor.regenerate_access_code!
    redirect_to edit_admin_investor_path(@investor),
                notice: "New access code generated: #{@investor.access_code}"
  end

  private

  def set_investor
    @investor = Investor.find(params[:id])
  end

  def investor_params
    params.require(:investor).permit(
      :name, :fund_name, :email, :watermark_label,
      :access_expires_at, :active, :access_code
    )
  end
end
