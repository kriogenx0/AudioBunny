module JwtService
  SECRET    = ENV.fetch("JWT_SECRET", "audiobunny-dev-secret-changeme")
  ALGORITHM = "HS256"
  TTL       = 30 * 24 * 60 * 60 # 30 days

  def self.encode(user_id)
    payload = { sub: user_id, exp: Time.now.to_i + TTL }
    JWT.encode(payload, SECRET, ALGORITHM)
  end

  def self.decode(token)
    payload = JWT.decode(token, SECRET, true, algorithms: [ALGORITHM]).first
    payload["sub"]
  rescue JWT::DecodeError
    nil
  end

  def self.decode_user(request)
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")
    user_id = decode(header.delete_prefix("Bearer "))
    return nil unless user_id
    User.find_by(id: user_id)
  end
end
