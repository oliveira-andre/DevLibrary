# The in-app reader (002 US3). The page is a shell: the browser loads the engine for the
# book's format and resumes at the position saved on the account (contracts/reader-client.md).
class Books::ReadersController < ApplicationController
  include BookScoped
  layout "reader"

  def show
    @position = ReadingPosition.for(user: Current.user, book: @book)
  end
end
