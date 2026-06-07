class PresetInstall < ApplicationRecord
  belongs_to :user
  belongs_to :preset
  validates :user_id, uniqueness: { scope: :preset_id }
  validates :status, inclusion: { in: %w[queued completed] }
end
