class Api::V1::Accounts::ClinicAppointmentsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_clinic_appointment, only: [:update, :destroy]

  def index
    @appointments = filtered_appointments.includes(:contact).order(:starts_at).limit(100)

    render json: {
      appointments: @appointments.map { |appointment| appointment_payload(appointment) },
      summary: summary_payload
    }
  end

  def create
    # Keep overlap validation safe when two receptionists book at the same time.
    Current.account.with_lock do
      @clinic_appointment = Current.account.clinic_appointments.new(appointment_params)
      assign_contact
      @clinic_appointment.save!
    end

    render json: appointment_payload(@clinic_appointment), status: :created
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'This provider already has an appointment at that time.' }, status: :conflict
  end

  def update
    Current.account.with_lock do
      @clinic_appointment.reload
      @clinic_appointment.assign_attributes(appointment_params)
      assign_contact if appointment_params.key?(:contact_id)
      @clinic_appointment.save!
    end

    render json: appointment_payload(@clinic_appointment)
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'This provider already has an appointment at that time.' }, status: :conflict
  end

  def destroy
    @clinic_appointment.destroy!
    head :ok
  end

  private

  def filtered_appointments
    appointments = Current.account.clinic_appointments

    case params[:filter]
    when 'upcoming'
      appointments.where(starts_at: Time.current..).where.not(status: %w[cancelled no_show])
    when 'available'
      appointments.where(status: :available).where(starts_at: Time.current..)
    when 'recovery'
      appointments.recovery_queue.order(starts_at: :desc)
    else
      appointments
    end
  end

  def summary_payload
    appointments = Current.account.clinic_appointments
    month = Time.current.beginning_of_month..Time.current.end_of_month

    {
      upcoming_today: appointments.where(starts_at: Time.current..Time.current.end_of_day)
                                 .where(status: %w[requested confirmed]).count,
      open_slots_48h: appointments.available.where(starts_at: Time.current..48.hours.from_now).count,
      recovery_cases: appointments.recovery_queue.count,
      confirmed_value_this_month: appointments.where(status: %w[confirmed completed], starts_at: month)
                                              .sum(:amount_rupees)
    }
  end

  def appointment_payload(appointment)
    {
      id: appointment.id,
      contact_id: appointment.contact_id,
      patient_name: appointment.contact&.name,
      patient_phone: appointment.contact&.phone_number,
      provider_name: appointment.provider_name,
      service_name: appointment.service_name,
      starts_at: appointment.starts_at,
      ends_at: appointment.ends_at,
      amount_rupees: appointment.amount_rupees,
      status: appointment.status,
      source: appointment.source
    }
  end

  def set_clinic_appointment
    @clinic_appointment = Current.account.clinic_appointments.find(params[:id])
    authorize @clinic_appointment
  end

  def assign_contact
    contact_id = appointment_params[:contact_id]
    @clinic_appointment.contact = contact_id.present? ? Current.account.contacts.find(contact_id) : nil
  end

  def appointment_params
    params.require(:clinic_appointment).permit(
      :contact_id,
      :provider_name,
      :service_name,
      :starts_at,
      :ends_at,
      :amount_rupees,
      :status,
      :source
    )
  end
end
