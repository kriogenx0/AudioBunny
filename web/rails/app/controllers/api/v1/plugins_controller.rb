class Api::V1::PluginsController < ApplicationController
  def index
    scope = current_user&.is_admin? ? Plugin.all : Plugin.where(status: "approved")

    if params[:q].present?
      like = "%#{params[:q]}%"
      scope = scope.where("name LIKE ? OR manufacturer LIKE ?", like, like)
    end
    scope = scope.where(is_free: true) if params[:is_free] == "true"

    scope = case params[:sort]
            when "manufacturer" then scope.order(:manufacturer, :name)
            when "newest"       then scope.order(created_at: :desc)
            else                     scope.order(:name)
            end

    fav_ids = current_user ? Favorite.where(user: current_user).pluck(:plugin_id).to_set : Set.new
    render json: scope.map { |p| plugin_json(p, fav_ids.include?(p.id)) }
  end

  def show
    plugin = Plugin.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless plugin
    favorited = current_user && Favorite.exists?(user: current_user, plugin: plugin)
    render json: plugin_json(plugin, !!favorited)
  end

  def create
    return render json: { error: "Unauthorized" }, status: :unauthorized unless current_user

    plugin = Plugin.new(
      name:            params[:name],
      manufacturer:    params[:manufacturer],
      category:        params[:category].presence || "instrument",
      formats:         Array(params[:formats]).join(","),
      plugin_type:     params[:plugin_type].presence || "VST 3",
      description:     params[:description],
      version:         params[:version],
      tags:            params[:tags],
      website_url:     params[:website_url],
      github_repo:     params[:github_repo],
      is_free:         params[:is_free] == true || params[:is_free] == "true",
      price_usd:       params[:price_usd].presence,
      submitted_by_id: current_user.id,
      status:          "pending"
    )

    if plugin.save
      render json: plugin_json(plugin, false), status: :created
    else
      render json: { errors: plugin.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def plugin_json(plugin, favorited = false)
    plugin.attributes.merge(
      "favorited"      => !!favorited,
      "formats"        => plugin.formats.to_s.split(",").map(&:strip).reject(&:empty?),
      "category"       => plugin.category.presence || "instrument",
      "submitted_by"   => plugin.submitted_by_id
    )
  end
end
