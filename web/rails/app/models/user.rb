class User < ApplicationRecord
  has_secure_password

  has_many :favorites,        dependent: :destroy
  has_many :preset_favorites, dependent: :destroy
  has_many :preset_installs,  dependent: :destroy
  has_many :submitted_plugins, class_name: "Plugin",
                               foreign_key: :submitted_by_id,
                               dependent: :nullify

  def is_admin?
    is_admin
  end

  validates :email,    presence: true,
                       uniqueness: { case_sensitive: false },
                       format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { minimum: 2, maximum: 30 }
end
