FactoryBot.define do
  factory :library_entry do
    library { association(:user).library }
    book { association(:book, :published) }
  end
end
