FactoryBot.define do
  factory :reading_position do
    user
    book { association(:book, :published) }
    location { "1" }
    progress { 0 }
    read_at { Time.current }
  end
end
