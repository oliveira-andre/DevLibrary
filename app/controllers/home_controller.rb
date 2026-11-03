# The home page: search box, the reader's collection and the newest books (002 US1, US2,
# US6). Signed-in only, through ApplicationController.
class HomeController < ApplicationController
  def show
    @collection = Current.user.library.search
    @recent = Book.recent
  end
end
