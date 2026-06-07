class CreatePresetFavorites < ActiveRecord::Migration[7.2]
  def change
    create_table :preset_favorites do |t|
      t.references :user,   null: false, foreign_key: true
      t.references :preset, null: false, foreign_key: true
      t.timestamps
    end
    add_index :preset_favorites, %i[user_id preset_id], unique: true
  end
end
