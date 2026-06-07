class Preset < ApplicationRecord
  belongs_to :plugin
  belongs_to :uploader, class_name: "User", optional: true

  has_many :preset_favorites, dependent: :destroy
  has_many :preset_installs,  dependent: :destroy

  validates :name,           presence: true
  validates :author,         presence: true
  validates :genre,          presence: true
  validates :file_extension, presence: true

  def downloadable?
    file_path.present?
  end
end
