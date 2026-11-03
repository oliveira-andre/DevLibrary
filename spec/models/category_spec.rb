require "rails_helper"

RSpec.describe Category, type: :model do
  it { is_expected.to have_many(:categorizations).dependent(:destroy) }
  it { is_expected.to have_many(:books).through(:categorizations) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(50) }

  it "squishes the name" do
    expect(create(:category, name: "  Dark   Fantasy ").name).to eq("Dark Fantasy")
  end

  it "rejects a name that differs only in case" do
    create(:category, name: "Fantasy")
    duplicate = build(:category, name: "fantasy")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include("has already been taken")
  end

  it "touches its books when renamed" do
    category = create(:category)
    book = create(:book, categories: [ category ])

    travel 1.minute do
      expect { category.update!(name: "Renamed") }.to change { book.reload.updated_at }
    end
  end

  describe ".cached_ordered" do
    before do
      create(:category, name: "Romance")
      create(:category, name: "Fantasy")
    end

    it "lists categories by name" do
      expect(Category.cached_ordered.map(&:name)).to eq(%w[Fantasy Romance])
    end

    context "with caching", :caching do
      it "serves a repeat call with only the version query" do
        Category.cached_ordered

        expect(count_queries { Category.cached_ordered }).to eq(1)
      end

      it "reflects a new or renamed category" do
        Category.cached_ordered
        travel(1.minute) do
          create(:category, name: "Horror")
          Category.find_by!(name: "Romance").update!(name: "Love")
        end

        expect(Category.cached_ordered.map(&:name)).to eq(%w[Fantasy Horror Love])
      end
    end
  end

  it "keeps its books when destroyed" do
    category = create(:category)
    book = create(:book, categories: [ category ])

    category.destroy!

    expect(Book.exists?(book.id)).to be(true)
    expect(book.reload.categories).to be_empty
  end
end
