class Api::V1::PresetsController < ApplicationController
  before_action :authenticate!, only: [:create]

  def index
    presets = Preset.includes(:plugin, :uploader)
    presets = presets.where(plugin_id: params[:plugin_id]) if params[:plugin_id].present?
    presets = presets.where(genre: params[:genre])          if params[:genre].present?
    presets = presets.where(is_community: true)             if params[:community] == "true"

    if params[:q].present?
      like = "%#{params[:q]}%"
      presets = presets.where(
        "presets.name LIKE ? OR presets.author LIKE ? OR presets.genre LIKE ? OR presets.tags LIKE ?",
        like, like, like, like
      )
    end

    presets = presets.order(is_community: :asc, name: :asc)

    fav_ids     = current_user ? PresetFavorite.where(user: current_user).pluck(:preset_id).to_set : Set.new
    install_ids = current_user ? PresetInstall.where(user: current_user).pluck(:preset_id).to_set  : Set.new

    render json: presets.map { |p| preset_json(p, fav_ids.include?(p.id), install_ids.include?(p.id)) }
  end

  def show
    preset = Preset.includes(:plugin, :uploader).find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless preset
    favorited = current_user && PresetFavorite.exists?(user: current_user, preset: preset)
    installed = current_user && PresetInstall.exists?(user: current_user, preset: preset)
    render json: preset_json(preset, !!favorited, !!installed)
  end

  def create
    preset = Preset.new(
      plugin_id:   params[:plugin_id],
      name:        params[:name],
      author:      params[:author].presence || @current_user.username,
      genre:       params[:genre],
      description: params[:description],
      tags:        params[:tags],
      is_community: true,
      uploader:    @current_user
    )

    if (file = params[:file])
      ext      = File.extname(file.original_filename).delete_prefix(".").downcase
      filename = "#{SecureRandom.hex(16)}.#{ext}"
      dest     = Rails.root.join("storage", "presets", filename)
      FileUtils.mkdir_p(dest.dirname)
      FileUtils.cp(file.tempfile.path, dest.to_s)
      preset.file_path      = filename
      preset.file_extension = ext
      preset.file_size_bytes = file.size
    else
      preset.file_extension = params[:file_extension].presence || "fxp"
    end

    if preset.save
      render json: preset_json(preset, false, false), status: :created
    else
      render json: { errors: preset.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def download
    preset = Preset.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found   unless preset
    return render json: { error: "No file" },   status: :not_found   unless preset.downloadable?

    path = Rails.root.join("storage", "presets", preset.file_path)
    return render json: { error: "File missing" }, status: :not_found unless File.exist?(path)

    send_file path.to_s,
      filename:    "#{preset.name}.#{preset.file_extension}",
      type:        "application/octet-stream",
      disposition: "attachment"
  end

  private

  def preset_json(preset, favorited = false, installed = false)
    {
      id:                 preset.id,
      plugin_id:          preset.plugin_id,
      plugin_name:        preset.plugin&.name,
      name:               preset.name,
      author:             preset.author,
      genre:              preset.genre,
      description:        preset.description,
      tags:               preset.tags ? preset.tags.split(",").map(&:strip) : [],
      file_extension:     preset.file_extension,
      file_size_bytes:    preset.file_size_bytes,
      is_downloadable:    preset.downloadable?,
      is_community:       preset.is_community,
      uploader_username:  preset.uploader&.username,
      favorited:          !!favorited,
      installed:          !!installed,
      created_at:         preset.created_at
    }
  end
end
