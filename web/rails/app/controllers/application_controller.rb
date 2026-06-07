class ApplicationController < ActionController::API
  def authenticate!
    @current_user = JwtService.decode_user(request)
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user ||= JwtService.decode_user(request)
  end
end
