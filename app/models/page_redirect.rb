class PageRedirect < ApplicationRecord
  belongs_to :page

  validates :old_path, presence: true, uniqueness: true
end
