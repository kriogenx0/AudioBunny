class CreatePresetInstalls < ActiveRecord::Migration[7.2]
  def change
    create_table :preset_installs do |t|
      t.references :user,   null: false, foreign_key: true
      t.references :preset, null: false, foreign_key: true
      # 'queued' = requested from web, 'completed' = macOS app finished install
      t.string :status, null: false, default: "completed"
      t.timestamps
    end
    add_index :preset_installs, %i[user_id preset_id], unique: true
  end
end
