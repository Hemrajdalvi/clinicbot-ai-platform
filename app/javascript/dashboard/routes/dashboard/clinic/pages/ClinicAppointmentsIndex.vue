<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useDebounceFn } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import ContactAPI from 'dashboard/api/contacts';
import ClinicAppointmentsAPI from 'dashboard/api/clinicAppointments';

const { t } = useI18n();
const router = useRouter();
const { accountScopedRoute } = useAccount();
const FILTERS = ['upcoming', 'available', 'recovery'];
const activeFilter = ref('upcoming');
const appointments = ref([]);
const summary = ref({});
const isLoading = ref(true);
const isSaving = ref(false);
const isDialogOpen = ref(false);
const selectedAppointment = ref(null);
const rescheduleFrom = ref(null);
const selectedContact = ref(null);
const patientSearch = ref('');
const patientResults = ref([]);
const isSearchingPatients = ref(false);
const formError = ref('');
const searchSequence = ref(0);

const blankForm = () => ({
  provider_name: '',
  service_name: '',
  starts_at: '',
  ends_at: '',
  amount_rupees: 0,
});
const form = reactive(blankForm());

const filterLabels = computed(() => ({
  upcoming: t('CLINIC_APPOINTMENTS.UPCOMING'),
  available: t('CLINIC_APPOINTMENTS.AVAILABLE'),
  recovery: t('CLINIC_APPOINTMENTS.RECOVERY'),
}));

const statusLabels = computed(() => ({
  available: t('CLINIC_APPOINTMENTS.AVAILABLE_STATUS'),
  requested: t('CLINIC_APPOINTMENTS.REQUESTED_STATUS'),
  confirmed: t('CLINIC_APPOINTMENTS.CONFIRMED_STATUS'),
  completed: t('CLINIC_APPOINTMENTS.COMPLETED_STATUS'),
  cancelled: t('CLINIC_APPOINTMENTS.CANCELLED_STATUS'),
  no_show: t('CLINIC_APPOINTMENTS.NO_SHOW_STATUS'),
}));
const emptyStateMessages = computed(() => ({
  upcoming: t('CLINIC_APPOINTMENTS.EMPTY_UPCOMING'),
  available: t('CLINIC_APPOINTMENTS.EMPTY_AVAILABLE'),
  recovery: t('CLINIC_APPOINTMENTS.EMPTY_RECOVERY'),
}));

const isBooking = computed(() =>
  Boolean(selectedAppointment.value || rescheduleFrom.value)
);
const dialogTitle = computed(() => {
  if (selectedAppointment.value)
    return t('CLINIC_APPOINTMENTS.BOOK_SLOT_TITLE');
  if (rescheduleFrom.value) return t('CLINIC_APPOINTMENTS.RESCHEDULE_TITLE');
  return t('CLINIC_APPOINTMENTS.NEW_SLOT_TITLE');
});

const money = value =>
  new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(Number(value || 0));

const localInputValue = date => {
  const localDate = new Date(
    date.getTime() - date.getTimezoneOffset() * 60_000
  );
  return localDate.toISOString().slice(0, 16);
};

const displayDateTime = date =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(date));

const loadAppointments = async () => {
  isLoading.value = true;
  try {
    const { data } = await ClinicAppointmentsAPI.getAppointments(
      activeFilter.value
    );
    appointments.value = data.appointments;
    summary.value = data.summary;
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('CLINIC_APPOINTMENTS.LOAD_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

const runPatientSearch = useDebounceFn(async query => {
  if (query.trim().length < 2) {
    patientResults.value = [];
    isSearchingPatients.value = false;
    return;
  }

  const requestId = searchSequence.value + 1;
  searchSequence.value = requestId;
  isSearchingPatients.value = true;
  try {
    const { data } = await ContactAPI.search(query.trim(), 1, 'name');
    if (requestId === searchSequence.value) {
      patientResults.value = data.payload || [];
    }
  } catch {
    if (requestId === searchSequence.value) patientResults.value = [];
  } finally {
    if (requestId === searchSequence.value) isSearchingPatients.value = false;
  }
}, 250);

watch(patientSearch, query => {
  if (selectedContact.value?.name === query) return;
  searchSequence.value += 1;
  selectedContact.value = null;
  runPatientSearch(query);
});

watch(activeFilter, loadAppointments);

const roundedStart = () => {
  const value = new Date(Date.now() + 60 * 60 * 1000);
  value.setMinutes(Math.ceil(value.getMinutes() / 15) * 15, 0, 0);
  return value;
};

const openNewSlot = () => {
  selectedAppointment.value = null;
  rescheduleFrom.value = null;
  selectedContact.value = null;
  patientSearch.value = '';
  patientResults.value = [];
  formError.value = '';

  const start = roundedStart();
  Object.assign(form, {
    ...blankForm(),
    starts_at: localInputValue(start),
    ends_at: localInputValue(new Date(start.getTime() + 30 * 60 * 1000)),
  });
  isDialogOpen.value = true;
};

const openBooking = appointment => {
  selectedAppointment.value = appointment;
  rescheduleFrom.value = null;
  selectedContact.value = null;
  patientSearch.value = '';
  patientResults.value = [];
  formError.value = '';
  Object.assign(form, {
    provider_name: appointment.provider_name,
    service_name: appointment.service_name,
    starts_at: localInputValue(new Date(appointment.starts_at)),
    ends_at: localInputValue(new Date(appointment.ends_at)),
    amount_rupees: appointment.amount_rupees,
  });
  isDialogOpen.value = true;
};

const openReschedule = appointment => {
  const previousStart = new Date(appointment.starts_at);
  const nextStart = new Date(Date.now() + 24 * 60 * 60 * 1000);
  nextStart.setHours(
    previousStart.getHours(),
    previousStart.getMinutes(),
    0,
    0
  );
  const duration =
    new Date(appointment.ends_at).getTime() - previousStart.getTime();

  selectedAppointment.value = null;
  rescheduleFrom.value = appointment;
  selectedContact.value = {
    id: appointment.contact_id,
    name: appointment.patient_name,
    phone_number: appointment.patient_phone,
  };
  patientSearch.value = appointment.patient_name || '';
  patientResults.value = [];
  formError.value = '';
  Object.assign(form, {
    provider_name: appointment.provider_name,
    service_name: appointment.service_name,
    starts_at: localInputValue(nextStart),
    ends_at: localInputValue(new Date(nextStart.getTime() + duration)),
    amount_rupees: appointment.amount_rupees,
  });
  isDialogOpen.value = true;
};

const selectPatient = contact => {
  selectedContact.value = contact;
  patientSearch.value = contact.name;
  patientResults.value = [];
};

const closeDialog = () => {
  if (isSaving.value) return;
  isDialogOpen.value = false;
};

const onStartChange = () => {
  if (!form.starts_at) return;
  const start = new Date(form.starts_at);
  const end = new Date(form.ends_at);
  if (!form.ends_at || end <= start) {
    form.ends_at = localInputValue(new Date(start.getTime() + 30 * 60 * 1000));
  }
};

const submitForm = async () => {
  formError.value = '';
  if (
    !form.provider_name.trim() ||
    !form.service_name.trim() ||
    !form.starts_at ||
    !form.ends_at
  ) {
    formError.value = t('CLINIC_APPOINTMENTS.FIELD_REQUIRED');
    return;
  }
  if (isBooking.value && !selectedContact.value?.id) {
    formError.value = t('CLINIC_APPOINTMENTS.PATIENT_REQUIRED');
    return;
  }
  if (new Date(form.ends_at) <= new Date(form.starts_at)) {
    formError.value = t('CLINIC_APPOINTMENTS.FIELD_REQUIRED');
    return;
  }

  let status = 'available';
  if (selectedAppointment.value) status = 'confirmed';
  if (rescheduleFrom.value) status = 'requested';

  const appointment = {
    contact_id: selectedContact.value?.id || null,
    provider_name: form.provider_name.trim(),
    service_name: form.service_name.trim(),
    starts_at: new Date(form.starts_at).toISOString(),
    ends_at: new Date(form.ends_at).toISOString(),
    amount_rupees: Math.max(0, Math.floor(Number(form.amount_rupees) || 0)),
    status,
    source: rescheduleFrom.value ? 'recovery' : 'manual',
  };

  isSaving.value = true;
  try {
    if (selectedAppointment.value) {
      await ClinicAppointmentsAPI.updateAppointment(
        selectedAppointment.value.id,
        appointment
      );
    } else {
      await ClinicAppointmentsAPI.createAppointment(appointment);
    }
    isDialogOpen.value = false;
    useAlert(t('CLINIC_APPOINTMENTS.SAVE_SUCCESS'));
    await loadAppointments();
  } catch (error) {
    formError.value =
      error.response?.data?.error || t('CLINIC_APPOINTMENTS.SAVE_ERROR');
  } finally {
    isSaving.value = false;
  }
};

const changeStatus = async (appointment, status) => {
  try {
    await ClinicAppointmentsAPI.updateAppointment(appointment.id, { status });
    useAlert(t('CLINIC_APPOINTMENTS.STATUS_SUCCESS'));
    await loadAppointments();
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('CLINIC_APPOINTMENTS.SAVE_ERROR')
    );
  }
};

const openPatientConversation = async appointment => {
  try {
    const { data } = await ContactAPI.getConversations(appointment.contact_id);
    const conversation = data.payload?.[0];

    if (!conversation) {
      useAlert(t('CLINIC_APPOINTMENTS.NO_CONVERSATION'));
      return;
    }

    router.push(
      accountScopedRoute('inbox_view_conversation', {
        type: 'conversation',
        id: conversation.id,
      })
    );
  } catch {
    useAlert(t('CLINIC_APPOINTMENTS.OPEN_CONVERSATION_ERROR'));
  }
};

const statusClass = status => {
  const classes = {
    available: 'bg-n-surface-2 text-n-slate-11',
    requested: 'bg-n-amber-3 text-n-amber-11',
    confirmed: 'bg-n-teal-3 text-n-teal-11',
    completed: 'bg-n-blue-3 text-n-blue-11',
    cancelled: 'bg-n-rose-3 text-n-rose-11',
    no_show: 'bg-n-rose-3 text-n-rose-11',
  };
  return classes[status] || classes.available;
};

onMounted(loadAppointments);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <header class="shrink-0 px-6 pt-6 pb-5 border-b border-n-weak">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 class="text-xl font-medium text-n-slate-12">
            {{ t('CLINIC_APPOINTMENTS.TITLE') }}
          </h1>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('CLINIC_APPOINTMENTS.DESCRIPTION') }}
          </p>
        </div>
        <button
          type="button"
          class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white rounded-lg bg-n-brand hover:bg-n-brand/90"
          @click="openNewSlot"
        >
          <span class="i-lucide-plus size-4" aria-hidden="true" />
          {{ t('CLINIC_APPOINTMENTS.ADD_SLOT') }}
        </button>
      </div>

      <div class="grid grid-cols-1 gap-3 mt-6 sm:grid-cols-2 xl:grid-cols-4">
        <article class="p-4 border rounded-xl border-n-weak bg-n-surface-2">
          <p class="text-sm text-n-slate-11">
            {{ t('CLINIC_APPOINTMENTS.TODAY') }}
          </p>
          <p class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ summary.upcoming_today || 0 }}
          </p>
        </article>
        <article class="p-4 border rounded-xl border-n-weak bg-n-surface-2">
          <p class="text-sm text-n-slate-11">
            {{ t('CLINIC_APPOINTMENTS.OPEN_48H') }}
          </p>
          <p class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ summary.open_slots_48h || 0 }}
          </p>
        </article>
        <article class="p-4 border rounded-xl border-n-weak bg-n-surface-2">
          <p class="text-sm text-n-slate-11">
            {{ t('CLINIC_APPOINTMENTS.FOLLOW_UPS') }}
          </p>
          <p class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ summary.recovery_cases || 0 }}
          </p>
        </article>
        <article class="p-4 border rounded-xl border-n-weak bg-n-surface-2">
          <p class="text-sm text-n-slate-11">
            {{ t('CLINIC_APPOINTMENTS.CONFIRMED_VALUE') }}
          </p>
          <p class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ money(summary.confirmed_value_this_month) }}
          </p>
        </article>
      </div>

      <nav
        class="flex gap-2 mt-6 overflow-x-auto"
        :aria-label="t('CLINIC_APPOINTMENTS.TITLE')"
      >
        <button
          v-for="filter in FILTERS"
          :key="filter"
          type="button"
          class="px-3 py-2 text-sm rounded-lg whitespace-nowrap"
          :class="
            activeFilter === filter
              ? 'bg-n-slate-12 text-n-surface-1'
              : 'text-n-slate-11 hover:bg-n-surface-3'
          "
          :aria-current="activeFilter === filter ? 'page' : undefined"
          @click="activeFilter = filter"
        >
          {{ filterLabels[filter] }}
        </button>
      </nav>
    </header>

    <main class="flex-1 px-6 py-5 overflow-y-auto">
      <div v-if="isLoading" class="py-20 text-sm text-center text-n-slate-11">
        {{ t('CLINIC_APPOINTMENTS.LOADING') }}
      </div>
      <div
        v-else-if="!appointments.length"
        class="flex flex-col items-center justify-center max-w-lg py-20 mx-auto text-center"
      >
        <span
          class="i-lucide-calendar-clock size-10 text-n-slate-8"
          aria-hidden="true"
        />
        <h2 class="mt-4 text-lg font-medium text-n-slate-12">
          {{ t('CLINIC_APPOINTMENTS.NO_APPOINTMENTS') }}
        </h2>
        <p class="mt-2 text-sm text-n-slate-11">
          {{ emptyStateMessages[activeFilter] }}
        </p>
        <button
          v-if="activeFilter !== 'recovery'"
          type="button"
          class="px-4 py-2 mt-5 text-sm font-medium text-white rounded-lg bg-n-brand hover:bg-n-brand/90"
          @click="openNewSlot"
        >
          {{ t('CLINIC_APPOINTMENTS.ADD_SLOT') }}
        </button>
      </div>

      <div v-else class="overflow-x-auto border rounded-xl border-n-weak">
        <table class="w-full min-w-[900px] text-left">
          <thead class="text-xs uppercase bg-n-surface-2 text-n-slate-10">
            <tr>
              <th class="px-4 py-3 font-medium">
                {{ t('CLINIC_APPOINTMENTS.DATE_TIME') }}
              </th>
              <th class="px-4 py-3 font-medium">
                {{ t('CLINIC_APPOINTMENTS.PATIENT') }}
              </th>
              <th class="px-4 py-3 font-medium">
                {{ t('CLINIC_APPOINTMENTS.SERVICE_PROVIDER') }}
              </th>
              <th class="px-4 py-3 font-medium">
                {{ t('CLINIC_APPOINTMENTS.STATUS') }}
              </th>
              <th class="px-4 py-3 font-medium">
                {{ t('CLINIC_APPOINTMENTS.VALUE') }}
              </th>
              <th class="px-4 py-3 font-medium">
                {{ t('CLINIC_APPOINTMENTS.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr
              v-for="appointment in appointments"
              :key="appointment.id"
              class="text-sm"
            >
              <td class="px-4 py-4 text-n-slate-12">
                {{ displayDateTime(appointment.starts_at) }}
              </td>
              <td class="px-4 py-4">
                <div class="font-medium text-n-slate-12">
                  {{
                    appointment.patient_name ||
                    t('CLINIC_APPOINTMENTS.AVAILABLE_STATUS')
                  }}
                </div>
                <div
                  v-if="appointment.patient_phone"
                  class="mt-1 text-xs text-n-slate-10"
                >
                  {{ appointment.patient_phone }}
                </div>
              </td>
              <td class="px-4 py-4">
                <div class="font-medium text-n-slate-12">
                  {{ appointment.service_name }}
                </div>
                <div class="mt-1 text-xs text-n-slate-10">
                  {{ appointment.provider_name }}
                </div>
              </td>
              <td class="px-4 py-4">
                <span
                  class="inline-flex px-2.5 py-1 text-xs font-medium rounded-full"
                  :class="statusClass(appointment.status)"
                >
                  {{ statusLabels[appointment.status] }}
                </span>
              </td>
              <td class="px-4 py-4 text-n-slate-12">
                {{ money(appointment.amount_rupees) }}
              </td>
              <td class="px-4 py-4">
                <div class="flex flex-wrap gap-2">
                  <button
                    v-if="appointment.contact_id"
                    type="button"
                    class="px-3 py-1.5 text-xs font-medium rounded-lg text-n-slate-11 bg-n-surface-2 hover:bg-n-surface-3"
                    @click="openPatientConversation(appointment)"
                  >
                    {{ t('CLINIC_APPOINTMENTS.OPEN_CONVERSATION') }}
                  </button>
                  <button
                    v-if="appointment.status === 'available'"
                    type="button"
                    class="px-3 py-1.5 text-xs font-medium rounded-lg text-n-brand bg-n-brand/10 hover:bg-n-brand/20"
                    @click="openBooking(appointment)"
                  >
                    {{ t('CLINIC_APPOINTMENTS.BOOK_SLOT') }}
                  </button>
                  <button
                    v-if="
                      ['cancelled', 'no_show'].includes(appointment.status) &&
                      appointment.contact_id
                    "
                    type="button"
                    class="px-3 py-1.5 text-xs font-medium rounded-lg text-n-brand bg-n-brand/10 hover:bg-n-brand/20"
                    @click="openReschedule(appointment)"
                  >
                    {{ t('CLINIC_APPOINTMENTS.RESCHEDULE') }}
                  </button>
                  <template v-if="appointment.status === 'requested'">
                    <button
                      type="button"
                      class="px-3 py-1.5 text-xs font-medium rounded-lg text-n-teal-11 bg-n-teal-3 hover:opacity-80"
                      @click="changeStatus(appointment, 'confirmed')"
                    >
                      {{ t('CLINIC_APPOINTMENTS.CONFIRM') }}
                    </button>
                    <button
                      type="button"
                      class="px-3 py-1.5 text-xs font-medium rounded-lg text-n-rose-11 bg-n-rose-3 hover:opacity-80"
                      @click="changeStatus(appointment, 'cancelled')"
                    >
                      {{ t('CLINIC_APPOINTMENTS.CANCEL') }}
                    </button>
                  </template>
                  <template v-if="appointment.status === 'confirmed'">
                    <button
                      type="button"
                      class="px-3 py-1.5 text-xs font-medium rounded-lg text-n-blue-11 bg-n-blue-3 hover:opacity-80"
                      @click="changeStatus(appointment, 'completed')"
                    >
                      {{ t('CLINIC_APPOINTMENTS.COMPLETE') }}
                    </button>
                    <button
                      type="button"
                      class="px-3 py-1.5 text-xs font-medium rounded-lg text-n-rose-11 bg-n-rose-3 hover:opacity-80"
                      @click="changeStatus(appointment, 'no_show')"
                    >
                      {{ t('CLINIC_APPOINTMENTS.MARK_NO_SHOW') }}
                    </button>
                    <button
                      type="button"
                      class="px-3 py-1.5 text-xs font-medium rounded-lg text-n-rose-11 bg-n-rose-3 hover:opacity-80"
                      @click="changeStatus(appointment, 'cancelled')"
                    >
                      {{ t('CLINIC_APPOINTMENTS.CANCEL') }}
                    </button>
                  </template>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </main>

    <div
      v-if="isDialogOpen"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40"
      role="presentation"
      @click.self="closeDialog"
      @keydown.esc="closeDialog"
    >
      <section
        role="dialog"
        aria-modal="true"
        :aria-label="dialogTitle"
        class="w-full max-w-xl p-6 overflow-y-auto bg-n-surface-1 rounded-2xl max-h-[90vh]"
      >
        <div class="flex items-start justify-between gap-4">
          <div>
            <h2 class="text-lg font-medium text-n-slate-12">
              {{ dialogTitle }}
            </h2>
            <p class="mt-1 text-sm text-n-slate-11">
              {{
                isBooking
                  ? t('CLINIC_APPOINTMENTS.SELECT_PATIENT')
                  : t('CLINIC_APPOINTMENTS.EMPTY_AVAILABLE')
              }}
            </p>
          </div>
          <button
            type="button"
            class="p-2 rounded-lg text-n-slate-10 hover:bg-n-surface-3"
            :aria-label="t('CLINIC_APPOINTMENTS.CLOSE')"
            @click="closeDialog"
          >
            <span class="i-lucide-x size-5" aria-hidden="true" />
          </button>
        </div>

        <form class="mt-5 space-y-4" @submit.prevent="submitForm">
          <div v-if="isBooking" class="relative">
            <label
              class="block mb-1 text-sm font-medium text-n-slate-12"
              for="clinic-patient"
            >
              {{ t('CLINIC_APPOINTMENTS.PATIENT') }}
            </label>
            <input
              id="clinic-patient"
              v-model="patientSearch"
              type="search"
              autocomplete="off"
              class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              :placeholder="t('CLINIC_APPOINTMENTS.SEARCH_PATIENT')"
            />
            <ul
              v-if="patientResults.length"
              class="absolute z-10 w-full mt-1 overflow-y-auto border rounded-lg shadow-lg border-n-weak bg-n-surface-1 max-h-52"
            >
              <li v-for="contact in patientResults" :key="contact.id">
                <button
                  type="button"
                  class="w-full px-3 py-2 text-left hover:bg-n-surface-2"
                  @click="selectPatient(contact)"
                >
                  <span class="block text-sm font-medium text-n-slate-12">{{
                    contact.name
                  }}</span>
                  <span class="block mt-0.5 text-xs text-n-slate-10">{{
                    contact.phone_number || contact.email
                  }}</span>
                </button>
              </li>
            </ul>
            <p
              v-else-if="isSearchingPatients"
              class="mt-1 text-xs text-n-slate-10"
            >
              {{ t('CLINIC_APPOINTMENTS.LOADING') }}
            </p>
            <p v-else-if="selectedContact" class="mt-1 text-xs text-n-teal-11">
              {{ selectedContact.name }}
            </p>
            <p
              v-if="selectedContact?.phone_number"
              class="mt-1 text-xs text-n-slate-10"
            >
              {{ selectedContact.phone_number }}
            </p>
            <p
              v-else-if="patientSearch.trim().length >= 2"
              class="mt-1 text-xs text-n-slate-10"
            >
              {{ t('CLINIC_APPOINTMENTS.NO_PATIENT_RESULTS') }}
            </p>
          </div>

          <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <label class="block text-sm font-medium text-n-slate-12">
              {{ t('CLINIC_APPOINTMENTS.PROVIDER') }}
              <input
                v-model="form.provider_name"
                type="text"
                maxlength="120"
                required
                class="w-full px-3 py-2 mt-1 text-sm font-normal border rounded-lg border-n-weak bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              />
            </label>
            <label class="block text-sm font-medium text-n-slate-12">
              {{ t('CLINIC_APPOINTMENTS.SERVICE') }}
              <input
                v-model="form.service_name"
                type="text"
                maxlength="120"
                required
                class="w-full px-3 py-2 mt-1 text-sm font-normal border rounded-lg border-n-weak bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              />
            </label>
            <label class="block text-sm font-medium text-n-slate-12">
              {{ t('CLINIC_APPOINTMENTS.STARTS_AT') }}
              <input
                v-model="form.starts_at"
                type="datetime-local"
                required
                class="w-full px-3 py-2 mt-1 text-sm font-normal border rounded-lg border-n-weak bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
                @change="onStartChange"
              />
            </label>
            <label class="block text-sm font-medium text-n-slate-12">
              {{ t('CLINIC_APPOINTMENTS.ENDS_AT') }}
              <input
                v-model="form.ends_at"
                type="datetime-local"
                required
                class="w-full px-3 py-2 mt-1 text-sm font-normal border rounded-lg border-n-weak bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
              />
            </label>
          </div>

          <label class="block text-sm font-medium text-n-slate-12">
            {{ t('CLINIC_APPOINTMENTS.AMOUNT') }}
            <input
              v-model.number="form.amount_rupees"
              type="number"
              min="0"
              step="1"
              class="w-full px-3 py-2 mt-1 text-sm font-normal border rounded-lg border-n-weak bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
            />
          </label>

          <p
            v-if="formError"
            role="alert"
            class="p-3 text-sm rounded-lg bg-n-rose-3 text-n-rose-11"
          >
            {{ formError }}
          </p>

          <div class="flex justify-end gap-3 pt-2">
            <button
              type="button"
              class="px-4 py-2 text-sm font-medium rounded-lg text-n-slate-11 hover:bg-n-surface-3"
              :disabled="isSaving"
              @click="closeDialog"
            >
              {{ t('CLINIC_APPOINTMENTS.CLOSE') }}
            </button>
            <button
              type="submit"
              class="px-4 py-2 text-sm font-medium text-white rounded-lg bg-n-brand hover:bg-n-brand/90 disabled:opacity-60"
              :disabled="isSaving"
            >
              {{
                isSaving
                  ? t('CLINIC_APPOINTMENTS.LOADING')
                  : isBooking
                    ? t('CLINIC_APPOINTMENTS.SAVE_BOOKING')
                    : t('CLINIC_APPOINTMENTS.SAVE_SLOT')
              }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </section>
</template>
