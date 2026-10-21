# ClinicBot AI — Product Blueprint and Delivery Status

## Product goal

Help clinics handle patient conversations and make better use of available appointment time. The platform is based on Chatwoot's account-scoped inbox, contacts, and channel integrations.

## Available in this repository

- ClinicBot AI installation branding.
- A clinic appointment board for publishing open slots, booking existing patient contacts, tracking appointment status, and rescheduling cancelled or missed appointments.
- The underlying Chatwoot inbox and its configured channels, including WhatsApp where a clinic has connected and approved a WhatsApp Business account.

The appointment board records estimated visit value only. It does not process payments, create UPI links, message patients automatically, or infer appointment availability from conversations. Teams open the patient's latest conversation and confirm bookings through their connected inbox.

## Production integrations still required

- Each clinic must connect and verify its own WhatsApp Business account and approved message templates before WhatsApp messages can be sent.
- UPI collection requires a merchant payment provider, business verification, credentials, webhook verification, and a refund workflow.
- Automated slot matching and reminders require clinic-configured services, provider schedules, patient consent, and delivery rules.
- Production hosting needs a secured database, Redis, encrypted secrets, backups, monitoring, and a public HTTPS domain.

## Privacy and product boundaries

Appointment records link to a patient contact and store scheduling details and an estimated value. Do not put diagnoses, treatment notes, or other clinical records in the appointment service label. Follow the clinic's retention and patient-consent policies for contact and messaging data.
