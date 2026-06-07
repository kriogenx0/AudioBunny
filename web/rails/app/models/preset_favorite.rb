class PresetFavorite < ApplicationRecord
  belongs_to :user
  belongs_to :preset
  validates :user_id, uniqueness: { scope: :preset_id }
end
