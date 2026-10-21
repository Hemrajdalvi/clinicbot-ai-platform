require 'rails_helper'

RSpec.describe ClinicAppointment do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:contact).optional }
  end

  describe 'validations' do
    let(:account) { create(:account) }
    let(:appointment) { build(:clinic_appointment, account: account) }

    it 'allows a provider to publish an open slot without a patient' do
      expect(appointment).to be_valid
    end

    it 'requires a patient for a requested appointment' do
      appointment.status = 'requested'

      expect(appointment).not_to be_valid
      expect(appointment.errors[:contact]).to be_present
    end

    it 'does not allow a patient from another account' do
      appointment.contact = create(:contact)
      appointment.status = 'confirmed'

      expect(appointment).not_to be_valid
      expect(appointment.errors[:contact]).to be_present
    end

    it 'rejects an overlapping active slot for the same provider' do
      create(:clinic_appointment, account: account, starts_at: appointment.starts_at, ends_at: appointment.ends_at)
      appointment.starts_at += 15.minutes
      appointment.ends_at += 15.minutes

      expect(appointment).not_to be_valid
      expect(appointment.errors[:starts_at]).to be_present
    end

    it 'allows the same time for a different provider' do
      create(:clinic_appointment, account: account, provider_name: 'Dr. One', starts_at: appointment.starts_at,
                                  ends_at: appointment.ends_at)
      appointment.provider_name = 'Dr. Two'

      expect(appointment).to be_valid
    end
  end

  describe 'status transitions' do
    let(:appointment) { create(:clinic_appointment, :confirmed) }

    it 'does not reopen a completed appointment' do
      appointment.update!(status: 'completed')
      appointment.status = 'confirmed'

      expect(appointment).not_to be_valid
      expect(appointment.errors[:status]).to be_present
    end
  end
end
