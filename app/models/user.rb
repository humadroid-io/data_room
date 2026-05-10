class User < ApplicationRecord
  has_secure_password

  enum :role, %i[admin viewer], default: :admin

  validates :name,  presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email, with: ->(e) { e.strip.downcase }

  def regenerate_api_token!
    update!(api_token: self.class.generate_api_token)
  end

  def self.generate_api_token
    "dr_" + SecureRandom.urlsafe_base64(32)
  end

  def self.authenticate_by_api_token(token)
    return nil if token.blank?
    find_by(api_token: token)
  end
end
