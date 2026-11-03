require "rails_helper"

RSpec.describe Categorization, type: :model do
  let!(:book) { create(:book) }
  let!(:category) { create(:category) }

  it "is unique per book and category" do
    Categorization.create!(book: book, category: category)

    expect(Categorization.new(book: book, category: category)).not_to be_valid
  end

  it "touches both the book and the category when created and destroyed" do
    categorization = nil

    travel 1.minute do
      expect { categorization = Categorization.create!(book: book, category: category) }
        .to change { book.reload.updated_at }.and change { category.reload.updated_at }
    end

    travel 2.minutes do
      expect { categorization.destroy! }
        .to change { book.reload.updated_at }.and change { category.reload.updated_at }
    end
  end
end
