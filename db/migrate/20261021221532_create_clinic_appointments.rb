class CreateClinicAppointments < ActiveRecord::Migration[7.1]
  def change
    create_table :clinic_appointments do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, type: :integer
      t.references :contact, null: true, foreign_key: { on_delete: :cascade }, type: :integer
      t.string :provider_name, null: false
      t.string :service_name, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :amount_rupees, null: false, default: 0
      t.string :status, null: false, default: 'available'
      t.string :source, null: false, default: 'manual'

      t.timestamps
    end

    add_index :clinic_appointments, [:account_id, :starts_at]
    add_index :clinic_appointments, [:contact_id, :starts_at]
    add_index :clinic_appointments,
              [:account_id, :provider_name, :starts_at],
              unique: true,
              where: "status IN ('available', 'requested', 'confirmed')",
              name: 'index_clinic_appointments_on_active_provider_slot'
  end
end
