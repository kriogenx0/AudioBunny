class CreatePresets < ActiveRecord::Migration[7.2]
  def change
    create_table :presets do |t|
      t.references :plugin,   null: false, foreign_key: true
      t.references :uploader, foreign_key: { to_table: :users }
      t.string  :name,            null: false
      t.string  :author,          null: false
      t.string  :genre,           null: false
      t.text    :description
      t.string  :tags
      t.string  :file_extension,  null: false
      t.string  :file_path
      t.integer :file_size_bytes
      t.boolean :is_community,    null: false, default: false
      t.timestamps
    end
  end
end
