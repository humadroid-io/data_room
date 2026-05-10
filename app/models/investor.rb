class Investor < ApplicationRecord
  has_many :page_views,    dependent: :destroy
  has_many :page_accesses, dependent: :destroy

  validates :name,        presence: true
  validates :access_code, presence: true, uniqueness: true,
                          length: { minimum: 6 },
                          format: { with: /\A[\w\-]+\z/, message: "may only contain letters, digits, _ and -" }
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :watermark_label, presence: true

  normalizes :email, with: ->(e) { e.presence && e.strip.downcase }

  before_validation :default_access_code, on: :create
  before_validation :default_watermark,   on: :create

  scope :usable, -> {
    where(active: true).where(
      "access_expires_at IS NULL OR access_expires_at > ?", Time.current
    )
  }

  def usable?
    active? && (access_expires_at.nil? || access_expires_at > Time.current)
  end

  def regenerate_access_code!
    update!(access_code: self.class.generate_access_code)
  end

  def self.generate_access_code
    SecureRandom.urlsafe_base64(18)
  end

  private

  def default_access_code
    self.access_code = self.class.generate_access_code if access_code.blank?
  end

  def default_watermark
    self.watermark_label ||= [ name, fund_name ].compact_blank.join(" — ").presence || access_code
  end
end
