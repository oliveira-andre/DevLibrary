require "rails_helper"

RSpec.describe Book::Search, type: :model do
  let(:fantasy) { create(:category, name: "Fantasy") }
  let(:romance) { create(:category, name: "Romance") }

  def published(title, authors: [], at: Time.current, **attributes)
    create(:book, :published, title: title, authors: authors, **attributes).tap do |book|
      book.update_columns(published_at: at)
    end
  end

  def titles(**options)
    Book.search(**options).map(&:title)
  end

  describe "matching" do
    let!(:cafe) { published("Café Noir", authors: [ "José Saramago" ]) }

    it "ignores case and accents" do
      expect(titles(query: "cafe")).to eq([ "Café Noir" ])
    end

    it "matches partial words" do
      expect(titles(query: "CAF")).to eq([ "Café Noir" ])
    end

    it "requires every term, in any order" do
      expect(titles(query: "noir cafe")).to eq([ "Café Noir" ])
      expect(titles(query: "noir dragon")).to be_empty
    end

    it "matches author names" do
      expect(titles(query: "saramago")).to eq([ "Café Noir" ])
    end

    it "treats % and _ in the query literally" do
      published("100% Pure")
      published("100 Pure")

      expect(titles(query: "100%")).to eq([ "100% Pure" ])
      expect(titles(query: "_")).to be_empty
    end

    it "never returns drafts or archived books" do
      create(:book, title: "Café Draft")
      create(:book, :archived, title: "Café Archived")

      expect(titles(query: "cafe")).to eq([ "Café Noir" ])
    end
  end

  describe "category filter" do
    let!(:dragon) { published("Dragon Song", categories: [ fantasy ]) }
    let!(:love) { published("Love Letters", categories: [ romance ]) }

    it "limits results to one category" do
      expect(titles(category: fantasy)).to eq([ "Dragon Song" ])
    end

    it "includes every category when none is chosen" do
      expect(titles(category: nil)).to contain_exactly("Dragon Song", "Love Letters")
    end

    it "combines with the search text" do
      expect(titles(query: "love", category: fantasy)).to be_empty
    end
  end

  describe "sorting" do
    let!(:older) { published("Alpha", at: 2.days.ago, average_rating: 3.5, reviews_count: 9) }
    let!(:newer) { published("Beta", at: 1.day.ago, average_rating: 4.8, reviews_count: 2) }
    let!(:newest) { published("Gamma", at: 1.hour.ago, average_rating: 4.8, reviews_count: 7) }

    it "defaults to newest without search text" do
      expect(titles).to eq(%w[Gamma Beta Alpha])
    end

    it "falls back to newest when relevance is asked for without search text" do
      expect(titles(sort: "relevance")).to eq(%w[Gamma Beta Alpha])
    end

    it "orders by title in both directions" do
      expect(titles(sort: "title_asc")).to eq(%w[Alpha Beta Gamma])
      expect(titles(sort: "title_desc")).to eq(%w[Gamma Beta Alpha])
    end

    it "orders top rated by average, then by number of reviews" do
      expect(titles(sort: "top_rated")).to eq(%w[Gamma Beta Alpha])
    end

    it "ignores an unknown sort" do
      expect(titles(sort: "random")).to eq(%w[Gamma Beta Alpha])
    end
  end

  it "defaults to relevance with search text, ranking an exact title above a partial match" do
    published("Noir Stories Collected Here", at: 1.hour.ago)
    published("Noir", at: 2.days.ago)

    expect(titles(query: "noir")).to eq([ "Noir", "Noir Stories Collected Here" ])
  end

  it "pages through results" do
    30.times { |n| published(format("Book %02d", n), at: n.minutes.ago) }

    expect(Book.search(page: 2, per: 24).size).to eq(6)
    expect(Book.search(page: 2, per: 24).first.title).to eq("Book 24")
  end

  context "with caching", :caching do
    let!(:dragon) { published("Dragon Song", categories: [ fantasy ]) }

    it "serves a repeat search with only the catalog version query" do
      Book.search(query: "dragon")

      expect(count_queries { Book.search(query: "dragon") }).to eq(1)
    end

    it "reflects a newly published matching book" do
      Book.search(query: "dragon")
      published("Dragon Moon")

      expect(titles(query: "dragon")).to contain_exactly("Dragon Song", "Dragon Moon")
    end

    it "misses the cache after a category is renamed" do
      Book.search(category: fantasy)
      travel(1.minute) { fantasy.update!(name: "Epic Fantasy") }

      expect(count_queries { Book.search(category: fantasy) }).to be > 1
    end

    it "reflects a change to a book's categories" do
      Book.search(category: romance)
      travel(1.minute) { dragon.categories << romance }

      expect(titles(category: romance)).to eq([ "Dragon Song" ])
    end
  end
end
