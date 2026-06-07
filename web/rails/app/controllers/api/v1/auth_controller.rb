class Api::V1::AuthController < ApplicationController
  before_action :authenticate!, only: [:me]

  def register
    user = User.new(
      email: params[:email],
      username: params[:username],
      password: params[:password]
    )
    if user.save
      render json: { token: JwtService.encode(user.id), user: user_json(user) }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    # Accept email or username in the "login" field
    user = User.find_by(email: params[:login]) ||
           User.find_by(username: params[:login])
    if user&.authenticate(params[:password])
      render json: { token: JwtService.encode(user.id), user: user_json(user) }
    else
      render json: { error: "Invalid credentials" }, status: :unauthorized
    end
  end

  def me
    render json: user_json(@current_user)
  end

  private

  def user_json(user)
    { id: user.id, email: user.email, username: user.username,
      is_admin: user.is_admin?, created_at: user.created_at }
  end
end
