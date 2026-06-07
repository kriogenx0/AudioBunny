class Plugin < ApplicationRecord
  has_many :favorites, dependent: :destroy
  has_many :presets,   dependent: :destroy

  validates :name,        presence: true
  validates :manufacturer, presence: true
  validates :plugin_type,  presence: true
end
