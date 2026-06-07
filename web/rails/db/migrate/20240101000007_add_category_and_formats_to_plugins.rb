class AddCategoryAndFormatsToPlugins < ActiveRecord::Migration[7.2]
  def change
    add_column :plugins, :category, :string, null: false, default: "instrument"
    add_column :plugins, :formats,  :string  # comma-separated: "AU,VST3"
    add_column :plugins, :website_url, :string
    add_column :plugins, :github_repo, :string
  end
end
