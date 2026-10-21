require 'rails_helper'

RSpec.describe 'Clinic appointments API', type: :request do
  let(:account) { create(:account) }

  def appointment_params(attributes = {})
    {
      provider_name: 'Dr. Asha Mehta',
      service_name: 'Consultation',
      starts_at: 2.days.from_now.change(sec: 0),
      ends_at: 2.days.from_now.change(sec: 0) + 30.minutes,
      amount_rupees: 500,
      status: 'available',
      source: 'manual'
    }.merge(attributes)
  end

  describe 'GET /api/v1/accounts/:account_id/clinic_appointments' do
    it 'requires authentication' do
      get "/api/v1/accounts/#{account.id}/clinic_appointments", params: { filter: 'upcoming' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns only appointments for the selected account' do
      admin = create(:user, account: account, role: :administrator)
      own_appointment = create(:clinic_appointment, account: account)
      create(:clinic_appointment, account: create(:account))

      get "/api/v1/accounts/#{account.id}/clinic_appointments",
          params: { filter: 'available' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['appointments'].pluck('id')).to eq([own_appointment.id])
    end
  end

  describe 'POST /api/v1/accounts/:account_id/clinic_appointments' do
    let(:agent) { create(:user, account: account, role: :agent) }

    it 'creates an open slot for an agent' do
      post "/api/v1/accounts/#{account.id}/clinic_appointments",
           params: { clinic_appointment: appointment_params }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['status']).to eq('available')
    end

    it 'rejects a patient from another account' do
      other_contact = create(:contact)

      post "/api/v1/accounts/#{account.id}/clinic_appointments",
           params: { clinic_appointment: appointment_params(contact_id: other_contact.id, status: 'confirmed') },
           headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/clinic_appointments/:id' do
    it 'puts a confirmed no-show into the recovery queue' do
      admin = create(:user, account: account, role: :administrator)
      appointment = create(:clinic_appointment, :confirmed, account: account)

      patch "/api/v1/accounts/#{account.id}/clinic_appointments/#{appointment.id}",
            params: { clinic_appointment: { status: 'no_show' } }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(appointment.reload).to be_no_show

      get "/api/v1/accounts/#{account.id}/clinic_appointments", params: { filter: 'recovery' },
                                                                headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['appointments'].pluck('id')).to eq([appointment.id])
    end
  end
end
