FactoryBot.define do
  # Every user already has a library, created with the account. This factory returns it.
  factory :library do
    initialize_with { association(:user).library }
    to_create { |library| library.save! }
  end
end
