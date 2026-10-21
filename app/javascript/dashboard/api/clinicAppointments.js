/* global axios */

import ApiClient from './ApiClient';

class ClinicAppointmentsAPI extends ApiClient {
  constructor() {
    super('clinic_appointments', { accountScoped: true });
  }

  getAppointments(filter = 'upcoming') {
    return axios.get(this.url, { params: { filter } });
  }

  createAppointment(appointment) {
    return axios.post(this.url, { clinic_appointment: appointment });
  }

  updateAppointment(id, appointment) {
    return axios.patch(`${this.url}/${id}`, {
      clinic_appointment: appointment,
    });
  }
}

export default new ClinicAppointmentsAPI();
