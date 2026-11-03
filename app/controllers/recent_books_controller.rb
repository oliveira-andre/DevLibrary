# "See more" on the home page: the next 50 newest books after a keyset cursor (002 FR-003).
class RecentBooksController < ApplicationController
  def index
    @recent = Book.recent(before: params[:before])
  end
end
