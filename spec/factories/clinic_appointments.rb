FactoryBot.define do
  factory :clinic_appointment do
    account
    provider_name { 'Dr. Asha Mehta' }
    service_name { 'Consultation' }
    starts_at { 1.day.from_now.change(sec: 0) }
    ends_at { starts_at + 30.minutes }
    amount_rupees { 500 }
    status { 'available' }
    source { 'manual' }

    trait :confirmed do
      status { 'confirmed' }
      contact { association :contact, account: account }
    end
  end
end
