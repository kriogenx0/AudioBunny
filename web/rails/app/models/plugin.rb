class Plugin < ApplicationRecord
  belongs_to :submitted_by, class_name: "User", foreign_key: :submitted_by_id, optional: true
  has_many :favorites, dependent: :destroy
  has_many :presets,   dependent: :destroy

  validates :name,        presence: true
  validates :manufacturer, presence: true
  validates :plugin_type,  presence: true
  validates :status, inclusion: { in: %w[pending approved rejected] }
end
