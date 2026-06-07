Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login",    to: "auth#login"
      get  "auth/me",       to: "auth#me"

      get "plugins",     to: "plugins#index"
      get "plugins/:id", to: "plugins#show"

      get   "presets",             to: "presets#index"
      get   "presets/:id",         to: "presets#show"
      post  "presets",             to: "presets#create"
      get   "presets/:id/download", to: "presets#download"

      get    "favorites/plugins",     to: "plugin_favorites#index"
      post   "favorites/plugins/:id", to: "plugin_favorites#create"
      delete "favorites/plugins/:id", to: "plugin_favorites#destroy"

      get    "favorites/presets",     to: "preset_favorites#index"
      post   "favorites/presets/:id", to: "preset_favorites#create"
      delete "favorites/presets/:id", to: "preset_favorites#destroy"

      get    "installs/presets",        to: "preset_installs#index"
      post   "installs/presets/:id",    to: "preset_installs#create"
      patch  "installs/presets/:id",    to: "preset_installs#update"
      delete "installs/presets/:id",    to: "preset_installs#destroy"
    end
  end
end
