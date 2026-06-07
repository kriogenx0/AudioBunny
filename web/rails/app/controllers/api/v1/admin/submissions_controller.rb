class Api::V1::Admin::SubmissionsController < ApplicationController
  before_action :authenticate!
  before_action :require_admin!

  def index
    plugins = Plugin.includes(:submitted_by).where(status: "pending").order(created_at: :desc)
    presets = Preset.includes(:plugin, :uploader).where(status: "pending").order(created_at: :desc)
    render json: {
      plugins: plugins.map { |p| plugin_json(p) },
      presets: presets.map { |p| preset_json(p) },
    }
  end

  def update_plugin
    plugin = Plugin.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless plugin
    plugin.update!(status: params.require(:status))
    render json: { ok: true, status: plugin.status }
  end

  def update_preset
    preset = Preset.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless preset
    preset.update!(status: params.require(:status))
    render json: { ok: true, status: preset.status }
  end

  private

  def require_admin!
    render json: { error: "Forbidden" }, status: :forbidden unless @current_user.is_admin?
  end

  def plugin_json(plugin)
    plugin.attributes.merge(
      "formats"            => plugin.formats.to_s.split(",").map(&:strip).reject(&:empty?),
      "category"           => plugin.category.presence || "instrument",
      "submitted_by"       => plugin.submitted_by ? { id: plugin.submitted_by.id, username: plugin.submitted_by.username } : nil
    )
  end

  def preset_json(preset)
    {
      id: preset.id, name: preset.name, author: preset.author, genre: preset.genre,
      description: preset.description, file_extension: preset.file_extension,
      status: preset.status, is_community: preset.is_community,
      plugin_id: preset.plugin_id, plugin_name: preset.plugin&.name,
      uploader_username: preset.uploader&.username, created_at: preset.created_at,
    }
  end
end
