FactoryBot.define do
  factory :bookmark do
    user
    book { association(:book, :published) }
    sequence(:location) { |n| n.to_s }
    progress { 10 }
  end
end
