class CreateFavorites < ActiveRecord::Migration[7.2]
  def change
    create_table :favorites do |t|
      t.references :user,   null: false, foreign_key: true
      t.references :plugin, null: false, foreign_key: true
      t.timestamps
    end
    add_index :favorites, %i[user_id plugin_id], unique: true
  end
end
