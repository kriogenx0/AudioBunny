class Api::V1::PluginFavoritesController < ApplicationController
  before_action :authenticate!

  def index
    plugins = Plugin.joins(:favorites).where(favorites: { user: @current_user })
    render json: plugins.map { |p| p.attributes.merge("favorited" => true) }
  end

  def create
    plugin = Plugin.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless plugin
    Favorite.find_or_create_by!(user: @current_user, plugin: plugin)
    render json: { ok: true }, status: :created
  end

  def destroy
    fav = Favorite.find_by(user: @current_user, plugin_id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless fav
    fav.destroy
    render json: { ok: true }
  end
end
