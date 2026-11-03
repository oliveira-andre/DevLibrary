FactoryBot.define do
  factory :note do
    user
    book { association(:book, :published) }
    location { "1" }
    progress { 10 }
    content { FFaker::Lorem.sentence }
  end
end
