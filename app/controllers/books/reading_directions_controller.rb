# The reader's own reading direction for one book (002 FR-026, 001 FR-039). Blank goes back
# to the book's direction. The reader updates from the streamed preferences.
class Books::ReadingDirectionsController < ApplicationController
  include BookScoped

  def update
    @position = ReadingPosition.set_direction!(user: Current.user, book: @book, direction: params[:direction].presence)
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_content
  end
end
