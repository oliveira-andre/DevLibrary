FactoryBot.define do
  factory :review do
    user
    book { association(:book, :published) }
    rating { 4 }
    content { FFaker::Lorem.paragraph }
  end
end
