# Saves the reader's place on every page turn (002 FR-023). The browser's outbox retries
# until this answers; the newest read_at always wins (001 ReadingPosition.record!), so
# late or repeated saves are harmless.
class Books::ReadingPositionsController < ApplicationController
  include BookScoped

  def update
    ReadingPosition.record!(user: Current.user, book: @book,
                            location: params[:location], progress: params[:progress], read_at: params[:read_at])
    head :no_content
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_content
  end
end
