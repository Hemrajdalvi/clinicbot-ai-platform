import { flushPromises, mount } from '@vue/test-utils';
import ClinicAppointmentsIndex from './ClinicAppointmentsIndex.vue';

const mocks = vi.hoisted(() => ({
  getAppointments: vi.fn(),
  createAppointment: vi.fn(),
  updateAppointment: vi.fn(),
  searchContacts: vi.fn(),
  getConversations: vi.fn(),
  alert: vi.fn(),
  push: vi.fn(),
  accountScopedRoute: vi.fn((name, params) => ({ name, params })),
}));

vi.mock('dashboard/api/clinicAppointments', () => ({
  default: {
    getAppointments: mocks.getAppointments,
    createAppointment: mocks.createAppointment,
    updateAppointment: mocks.updateAppointment,
  },
}));

vi.mock('dashboard/api/contacts', () => ({
  default: {
    search: mocks.searchContacts,
    getConversations: mocks.getConversations,
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: mocks.alert,
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountScopedRoute: mocks.accountScopedRoute }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('@vueuse/core', () => ({
  useDebounceFn: callback => callback,
}));

const appointment = {
  id: 42,
  contact_id: 7,
  patient_name: 'Asha Sharma',
  patient_phone: '+919876543210',
  provider_name: 'Dr. Asha Mehta',
  service_name: 'Consultation',
  starts_at: '2030-01-02T10:00:00.000Z',
  ends_at: '2030-01-02T10:30:00.000Z',
  amount_rupees: 500,
  status: 'no_show',
  source: 'manual',
};

const response = appointments => ({
  data: {
    appointments,
    summary: {
      upcoming_today: 0,
      open_slots_48h: 0,
      recovery_cases: 0,
      confirmed_value_this_month: 0,
    },
  },
});

const mountPage = () => mount(ClinicAppointmentsIndex);

describe('ClinicAppointmentsIndex', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getAppointments.mockResolvedValue(response([]));
    mocks.createAppointment.mockResolvedValue({ data: {} });
    mocks.updateAppointment.mockResolvedValue({ data: {} });
    mocks.searchContacts.mockResolvedValue({ data: { payload: [] } });
  });

  it('creates an open slot with its time and provider details', async () => {
    const wrapper = mountPage();
    await flushPromises();

    await wrapper.get('header button').trigger('click');
    const inputs = wrapper.findAll('form input');
    await inputs[0].setValue('Dr. Asha Mehta');
    await inputs[1].setValue('Consultation');
    await inputs[2].setValue('2030-01-02T10:00');
    await inputs[3].setValue('2030-01-02T10:30');
    await inputs[4].setValue('500');
    await wrapper.get('form').trigger('submit');
    await flushPromises();

    expect(mocks.createAppointment).toHaveBeenCalledWith(
      expect.objectContaining({
        contact_id: null,
        provider_name: 'Dr. Asha Mehta',
        service_name: 'Consultation',
        amount_rupees: 500,
        status: 'available',
      })
    );
    wrapper.unmount();
  });

  it('reschedules a no-show as a new requested appointment for the same patient', async () => {
    mocks.getAppointments.mockImplementation(async filter =>
      response(filter === 'recovery' ? [appointment] : [])
    );
    const wrapper = mountPage();
    await flushPromises();

    const recoveryTab = wrapper
      .findAll('nav button')
      .find(button => button.text().includes('CLINIC_APPOINTMENTS.RECOVERY'));
    await recoveryTab.trigger('click');
    await flushPromises();

    const rescheduleButton = wrapper
      .findAll('tbody button')
      .find(button => button.text().includes('CLINIC_APPOINTMENTS.RESCHEDULE'));
    await rescheduleButton.trigger('click');
    await wrapper.get('form').trigger('submit');
    await flushPromises();

    expect(mocks.createAppointment).toHaveBeenCalledWith(
      expect.objectContaining({
        contact_id: appointment.contact_id,
        provider_name: appointment.provider_name,
        service_name: appointment.service_name,
        amount_rupees: appointment.amount_rupees,
        status: 'requested',
        source: 'recovery',
      })
    );
    wrapper.unmount();
  });
});
