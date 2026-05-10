class Page < ApplicationRecord
  belongs_to :parent, class_name: "Page", optional: true, inverse_of: :children

  has_many :children, -> { order(:sort_order) },
           class_name: "Page", foreign_key: :parent_id, dependent: :destroy,
           inverse_of: :parent
  has_many :page_views,        dependent: :destroy
  has_many :page_accesses,     dependent: :destroy
  has_many :allowed_investors, through: :page_accesses, source: :investor
  has_many :page_redirects,    dependent: :destroy

  has_rich_text :body
  has_many_attached :documents

  enum :visibility, { draft: 0, public: 1, private: 2 }, prefix: true

  validates :title, presence: true
  validates :slug,  format: { with: /\A[a-z0-9\-]*\z/ }
  validates :path,  presence: true, uniqueness: true,
                    format: { with: %r{\A/[a-z0-9\-/]*\z} }

  before_validation :compute_path
  before_save       :build_redirect_if_path_changed
  after_save        :recompute_descendant_paths, if: :saved_change_to_path?
  after_save        :clear_allowlist_if_not_private

  scope :live,    -> { where.not(visibility: :draft) }
  scope :ordered, -> { order(:sort_order, :title) }

  def self.landing
    find_by(path: "/")
  end

  def root_landing?
    parent_id.nil? && slug.blank?
  end

  def visible_to?(investor)
    case visibility
    when "draft"   then false
    when "public"  then true
    when "private" then page_accesses.exists?(investor: investor)
    end
  end

  def visible_children_for(investor)
    children.live.select { |c| c.visible_to?(investor) }
  end

  private

  def compute_path
    self.path =
      if root_landing?
        "/"
      elsif parent.nil?
        "/#{slug}"
      else
        [ parent.path, slug ].join("/").gsub("//", "/")
      end
  end

  def build_redirect_if_path_changed
    return unless persisted? && path_changed? && path_was.present?

    page_redirects.build(old_path: path_was)
  end

  def recompute_descendant_paths
    children.reload.each do |child|
      child.parent = self
      child.save!
    end
  end

  def clear_allowlist_if_not_private
    page_accesses.delete_all unless visibility_private?
  end
end
