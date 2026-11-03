FactoryBot.define do
  factory :conversion do
    book { association(:book, :published, :epub) }
    requested_by { association(:user) }
    target_format { "pdf" }
    source_checksum { book.current_file_checksum }
  end
end
