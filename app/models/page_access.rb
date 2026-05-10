class PageAccess < ApplicationRecord
  belongs_to :page
  belongs_to :investor

  validates :investor_id, uniqueness: { scope: :page_id }
end
