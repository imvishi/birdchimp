class AddActiveStartAtIndexToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_index :appointments, :start_at, unique: true, where: "cancelled_at IS NULL",
              name: "index_appointments_on_active_start_at"
  end
end
