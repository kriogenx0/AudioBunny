class User < ApplicationRecord
  has_secure_password

  has_many :favorites,        dependent: :destroy
  has_many :preset_favorites, dependent: :destroy
  has_many :preset_installs,  dependent: :destroy
  has_many :uploaded_presets, class_name: "Preset",
                              foreign_key: :uploader_id,
                              dependent: :nullify

  validates :email,    presence: true,
                       uniqueness: { case_sensitive: false },
                       format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { minimum: 2, maximum: 30 }
end
