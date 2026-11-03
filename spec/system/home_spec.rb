require "rails_helper"

RSpec.describe "Home: newest books", type: :system do
  on_each_viewport do
    let(:user) { create(:user) }

    it "loads 50 books at a time until the list ends, without leaving the page" do
      insert_published_books(120)
      sign_in_and_wait_as(user)

      expect(page).to have_css("#recent_books .book-card", count: 50)

      click_link "See more"
      expect(page).to have_css("#recent_books .book-card", count: 100)
      expect(page.evaluate_script("window.scrollY")).to be > 0

      click_link "See more"
      expect(page).to have_css("#recent_books .book-card", count: 120)
      expect(page).to have_no_link("See more")
      expect(page).to have_current_path(home_path)
    end

    it "shows no book twice when another is published between loads" do
      insert_published_books(60)
      sign_in_and_wait_as(user)
      expect(page).to have_css("#recent_books .book-card", count: 50)

      create(:book, :published, title: "Fresh Arrival")
      click_link "See more"

      expect(page).to have_css("#recent_books .book-card", count: 60)
      ids = all("#recent_books .book-card").map { |card| card[:id] }
      expect(ids.uniq.size).to eq(60)
    end

    it "shows a friendly message when nothing is published yet" do
      sign_in_and_wait_as(user)

      expect(page).to have_text("No books yet")
      expect(page).to have_no_css("#recent_books")
    end
  end
end
