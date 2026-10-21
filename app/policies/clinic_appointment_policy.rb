class ClinicAppointmentPolicy < ApplicationPolicy
  def index?
    @account_user.present?
  end

  def create?
    index?
  end

  def update?
    index?
  end

  def destroy?
    @account_user&.administrator?
  end
end

ClinicAppointmentPolicy.prepend_mod_with('ClinicAppointmentPolicy')
