lock "~> 3.18"

set :application, "audiobunny"
set :repo_url,    ENV.fetch("REPO_URL", "git@github.com:yourusername/AudioBunny.git")
set :deploy_to,   "/var/www/audiobunny"
set :branch,      ENV.fetch("BRANCH", "main")

set :rbenv_type,  :user
set :rbenv_ruby,  File.read(File.expand_path("../../.ruby-version", __dir__)).strip

set :puma_threads, [4, 16]
set :puma_workers,  0
set :puma_bind,     "tcp://127.0.0.1:3000"
set :puma_state,    "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,      "#{shared_path}/tmp/pids/puma.pid"
set :puma_preload_app, true
set :puma_init_active_record, true

append :linked_files, ".env"
append :linked_dirs,  "log", "tmp/pids", "tmp/sockets", "storage/presets", "db"

set :keep_releases, 5
set :deploy_subdir, "web/rails"

namespace :deploy do
  after :updated, :migrate do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env, "production") do
          execute :bundle, "exec rails db:migrate"
        end
      end
    end
  end

  after :updated, :build_frontend do
    on roles(:web) do
      frontend_path = release_path.join("../../../web/frontend").cleanpath
      within frontend_path do
        execute :npm, "install --silent"
        execute :npm, "run build"
      end
    end
  end
end
