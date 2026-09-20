class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :note, limit: 200
      t.datetime :start_at, null: false
      t.datetime :cancelled_at

      t.timestamps
    end
  end
end
