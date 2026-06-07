class AddSubmissionsSupport < ActiveRecord::Migration[7.2]
  def change
    add_column :users,   :is_admin,        :boolean, null: false, default: false
    add_column :plugins, :status,          :string,  null: false, default: "approved"
    add_column :plugins, :submitted_by_id, :bigint
    add_column :presets, :status,          :string,  null: false, default: "approved"
    add_index :plugins, :status
    add_index :presets, :status
  end
end
