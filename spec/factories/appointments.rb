FactoryBot.define do
  factory :appointment do
    sequence(:name) { |n| "Person #{n}" }
    sequence(:email) { |n| "person#{n}@example.com" }
    start_at { Time.zone.local(2026, 9, 21, 9, 30) } # Monday, in the future for the frozen clock

    trait :cancelled do
      cancelled_at { Time.current }
    end

    # A booking whose slot has already passed. Skips validation, which would refuse a past slot.
    trait :past do
      start_at { Time.zone.local(2026, 9, 18, 10, 0) }
      to_create { |appointment| appointment.save!(validate: false) }
    end
  end
end
