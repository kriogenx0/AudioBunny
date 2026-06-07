class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :plugin
  validates :user_id, uniqueness: { scope: :plugin_id }
end
