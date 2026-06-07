server ENV.fetch("DEPLOY_HOST", "audiobunny.example.com"),
  user:  ENV.fetch("DEPLOY_USER", "deploy"),
  roles: %w[app db web]

set :rails_env, "production"
