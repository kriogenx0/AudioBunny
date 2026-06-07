class Api::V1::PresetFavoritesController < ApplicationController
  before_action :authenticate!

  def index
    install_ids = PresetInstall.where(user: @current_user).pluck(:preset_id).to_set
    presets = Preset.includes(:plugin).joins(:preset_favorites)
                    .where(preset_favorites: { user: @current_user })
    render json: presets.map { |p| preset_json(p, true, install_ids.include?(p.id)) }
  end

  def create
    preset = Preset.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless preset
    PresetFavorite.find_or_create_by!(user: @current_user, preset: preset)
    render json: { ok: true }, status: :created
  end

  def destroy
    fav = PresetFavorite.find_by(user: @current_user, preset_id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless fav
    fav.destroy
    render json: { ok: true }
  end

  private

  def preset_json(preset, favorited, installed)
    {
      id: preset.id, plugin_id: preset.plugin_id, plugin_name: preset.plugin&.name,
      name: preset.name, author: preset.author, genre: preset.genre,
      tags: preset.tags ? preset.tags.split(",").map(&:strip) : [],
      file_extension: preset.file_extension, is_downloadable: preset.downloadable?,
      is_community: preset.is_community, favorited: favorited, installed: installed,
      created_at: preset.created_at
    }
  end
end
