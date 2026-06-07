class Api::V1::PresetInstallsController < ApplicationController
  before_action :authenticate!

  # macOS app polls this for queued installs
  def index
    scope = PresetInstall.includes(preset: :plugin).where(user: @current_user)
    scope = scope.where(status: params[:status]) if params[:status].present?

    fav_ids = PresetFavorite.where(user: @current_user).pluck(:preset_id).to_set
    render json: scope.map { |pi| install_json(pi, fav_ids.include?(pi.preset_id)) }
  end

  # Web app creates a queued install; macOS app creates a completed install
  def create
    preset = Preset.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless preset

    status = params[:status] == "queued" ? "queued" : "completed"
    pi = PresetInstall.find_or_initialize_by(user: @current_user, preset: preset)
    pi.status = status
    pi.save!
    render json: install_json(pi, false), status: :created
  end

  # macOS app marks a queued install as completed
  def update
    pi = PresetInstall.includes(preset: :plugin)
                      .find_by(user: @current_user, preset_id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless pi
    pi.update!(status: "completed")
    render json: install_json(pi, PresetFavorite.exists?(user: @current_user, preset_id: pi.preset_id))
  end

  def destroy
    pi = PresetInstall.find_by(user: @current_user, preset_id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless pi
    pi.destroy
    render json: { ok: true }
  end

  private

  def install_json(pi, favorited)
    preset = pi.preset
    {
      install_id:      pi.id,
      status:          pi.status,
      id:              preset.id,
      plugin_id:       preset.plugin_id,
      plugin_name:     preset.plugin&.name,
      name:            preset.name,
      author:          preset.author,
      genre:           preset.genre,
      file_extension:  preset.file_extension,
      is_downloadable: preset.downloadable?,
      favorited:       favorited,
      installed:       true,
      created_at:      preset.created_at
    }
  end
end
