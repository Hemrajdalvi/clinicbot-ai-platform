import {
  CONVERSATION_PERMISSIONS,
  ROLES,
} from 'dashboard/constants/permissions';
import { frontendURL } from '../../../helper/URLHelper';
import ClinicAppointmentsIndex from './pages/ClinicAppointmentsIndex.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/clinic/appointments'),
    name: 'clinic_appointments_index',
    component: ClinicAppointmentsIndex,
    meta: {
      permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
    },
  },
];
