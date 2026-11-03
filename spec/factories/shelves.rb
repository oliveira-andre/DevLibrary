FactoryBot.define do
  factory :shelf do
    library { association(:user).library }
    sequence(:name) { |n| "Shelf #{n}" }
  end
end
