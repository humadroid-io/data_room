class PageView < ApplicationRecord
  belongs_to :investor
  belongs_to :page

  validates :viewed_at, presence: true
end
