class ClinicAppointment < ApplicationRecord
  belongs_to :account
  belongs_to :contact, optional: true

  enum :status, {
    available: 'available',
    requested: 'requested',
    confirmed: 'confirmed',
    completed: 'completed',
    cancelled: 'cancelled',
    no_show: 'no_show'
  }, validate: true

  SOURCES = %w[manual whatsapp phone website walk_in recovery].freeze
  ACTIVE_STATUSES = %w[available requested confirmed].freeze

  validates :provider_name, :service_name, :starts_at, :ends_at, presence: true
  validates :provider_name, :service_name, length: { maximum: 120 }
  validates :source, inclusion: { in: SOURCES }
  validates :amount_rupees, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :contact, presence: true, unless: :available?

  validate :contact_belongs_to_account
  validate :end_time_is_after_start_time
  validate :active_appointment_starts_in_future, if: :future_start_validation_required?
  validate :provider_has_no_overlapping_appointment, if: :active?
  validate :status_transition_is_allowed, on: :update

  before_validation :normalize_provider_and_service

  scope :upcoming, -> { where(starts_at: Time.current..) }
  scope :recovery_queue, -> { where(status: %w[cancelled no_show]).where.not(contact_id: nil) }

  private

  def normalize_provider_and_service
    self.provider_name = provider_name.strip if provider_name
    self.service_name = service_name.strip if service_name
  end

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def contact_belongs_to_account
    return if contact.blank? || contact.account_id == account_id

    errors.add(:contact, 'must belong to the same account')
  end

  def end_time_is_after_start_time
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, 'must be after the start time')
  end

  def future_start_validation_required?
    active? && (new_record? || will_save_change_to_starts_at? || will_save_change_to_status?)
  end

  def active_appointment_starts_in_future
    return if starts_at.blank? || starts_at > Time.current

    errors.add(:starts_at, 'must be in the future')
  end

  def provider_has_no_overlapping_appointment
    return if account.blank? || provider_name.blank? || starts_at.blank? || ends_at.blank?

    overlapping = account.clinic_appointments
                         .where('LOWER(provider_name) = LOWER(?)', provider_name.strip)
                         .where(status: ACTIVE_STATUSES)
                         .where('starts_at < ? AND ends_at > ?', ends_at, starts_at)
    overlapping = overlapping.where.not(id: id) if persisted?
    errors.add(:starts_at, 'overlaps another active appointment for this provider') if overlapping.exists?
  end

  def status_transition_is_allowed
    return unless will_save_change_to_status?

    allowed_statuses = {
      'available' => %w[available requested confirmed cancelled],
      'requested' => %w[requested confirmed cancelled],
      'confirmed' => %w[confirmed completed cancelled no_show],
      'completed' => %w[completed],
      'cancelled' => %w[cancelled],
      'no_show' => %w[no_show]
    }

    return if allowed_statuses.fetch(status_in_database, []).include?(status)

    errors.add(:status, 'cannot be changed from its current state')
  end
end
