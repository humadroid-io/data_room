class Admin::PagesController < Admin::BaseController
  before_action :set_page, only: %i[show edit update destroy]

  def index
    @pages = Page.includes(:parent).order(:path)
  end

  def show; end

  def new
    @page = Page.new(parent_id: params[:parent_id], visibility: :public)
  end

  def edit; end

  def create
    @page = Page.new(page_params)

    if @page.save
      sync_allowlist(@page, allowed_investor_ids)
      redirect_to admin_page_path(@page), notice: "Page created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @page.update(page_params)
      sync_allowlist(@page, allowed_investor_ids)
      redirect_to admin_page_path(@page), notice: "Page updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @page.destroy
    redirect_to admin_pages_path, notice: "Page deleted."
  end

  private

  def set_page
    @page = Page.find(params[:id])
  end

  def page_params
    params.require(:page).permit(
      :title, :slug, :parent_id, :sort_order, :visibility, :tldr, :body,
      documents: []
    )
  end

  def allowed_investor_ids
    Array(params.dig(:page, :allowed_investor_ids)).compact_blank.map(&:to_i)
  end

  def sync_allowlist(page, ids)
    return unless page.visibility_private?

    page.page_accesses.where.not(investor_id: ids).destroy_all
    existing = page.page_accesses.pluck(:investor_id)
    (ids - existing).each do |investor_id|
      page.page_accesses.create!(investor_id: investor_id)
    end
  end
end
