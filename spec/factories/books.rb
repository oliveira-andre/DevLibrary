FactoryBot.define do
  factory :book do
    sequence(:title) { |n| "#{FFaker::Book.title} #{n}" }
    authors { [ FFaker::Name.name ] }

    transient do
      file_fixture_name { nil }
    end

    after(:build) do |book, evaluator|
      if evaluator.file_fixture_name
        path = Rails.root.join("spec/fixtures/files", evaluator.file_fixture_name)
        book.file.attach(io: File.open(path), filename: evaluator.file_fixture_name)
      end
    end

    trait :with_file do
      file_fixture_name { "sample.pdf" }
    end

    trait :epub do
      file_fixture_name { "sample.epub" }
    end

    trait :manga do
      kind { "manga" }
      file_fixture_name { "manga.cbz" }
    end

    trait :with_cover do
      after(:build) do |book|
        book.cover.attach(io: File.open(Rails.root.join("spec/fixtures/files/cover.png")), filename: "cover.png")
      end
    end

    trait :published do
      with_file
      status { "published" }
    end

    trait :archived do
      with_file
      status { "archived" }
    end
  end
end
