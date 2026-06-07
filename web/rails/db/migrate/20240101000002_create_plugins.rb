class CreatePlugins < ActiveRecord::Migration[7.2]
  def change
    create_table :plugins do |t|
      t.string  :name,            null: false
      t.string  :manufacturer,    null: false
      t.string  :plugin_type,     null: false
      t.text    :description
      t.string  :version
      t.string  :tags
      t.string  :thumbnail_url
      t.string  :download_url
      t.integer :file_size_bytes
      t.boolean :is_free,         null: false, default: true
      t.decimal :price_usd,       precision: 8, scale: 2
      t.timestamps
    end
  end
end
