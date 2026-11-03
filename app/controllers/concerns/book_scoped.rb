# Controllers under a book resolve it from its public id through the visibility rules
# (002 contracts/http.md): drafts, deleted books and archived books the reader doesn't keep
# all answer 404 "This book isn't available" (FR-019). Controllers that don't need the book
# on every action skip `set_book` for those actions.
module BookScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_book
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_available
  end

  private
    def set_book
      @book = Book.find_visible_cached!(params[:book_id] || params[:id], user: Current.user)
    end

    def render_not_available
      respond_to do |format|
        format.html { render "books/not_available", status: :not_found, layout: "application" }
        format.any { head :not_found }
      end
    end
end
