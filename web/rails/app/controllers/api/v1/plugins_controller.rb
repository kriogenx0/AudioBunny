class Api::V1::PluginsController < ApplicationController
  def index
    plugins = Plugin.all

    if params[:q].present?
      like = "%#{params[:q]}%"
      plugins = plugins.where("name LIKE ? OR manufacturer LIKE ?", like, like)
    end
    plugins = plugins.where(plugin_type: params[:type]) if params[:type].present?
    plugins = plugins.where(is_free: params[:is_free] == "true") if params[:is_free].present?

    plugins = case params[:sort]
              when "manufacturer" then plugins.order(:manufacturer, :name)
              when "newest"       then plugins.order(created_at: :desc)
              else                     plugins.order(:name)
              end

    fav_ids = current_user ? Favorite.where(user: current_user).pluck(:plugin_id).to_set : Set.new
    render json: plugins.map { |p| plugin_json(p, fav_ids.include?(p.id)) }
  end

  def show
    plugin = Plugin.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless plugin
    favorited = current_user && Favorite.exists?(user: current_user, plugin: plugin)
    render json: plugin_json(plugin, !!favorited)
  end

  private

  def plugin_json(plugin, favorited = false)
    plugin.attributes.merge("favorited" => !!favorited)
  end
end
