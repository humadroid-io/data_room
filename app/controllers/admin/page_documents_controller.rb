class Admin::PageDocumentsController < Admin::BaseController
  def destroy
    page = Page.find(params[:page_id])
    document = page.documents.find(params[:id])
    document.purge_later
    redirect_to edit_admin_page_path(page), notice: "Document removed."
  end
end
