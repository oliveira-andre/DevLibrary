FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    name { FFaker::Name.name }
    password { "password123" }
    password_confirmation { "password123" }

    trait :admin do
      role { "admin" }
    end

    trait :nameless do
      name { "" }
    end

    trait :locked do
      locked_until { 10.minutes.from_now }
      lockout_count { 1 }
    end
  end
end
