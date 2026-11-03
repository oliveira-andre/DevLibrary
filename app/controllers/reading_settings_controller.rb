# Reading settings saved on the account (002 FR-031–FR-034): from the account menu (modal)
# or from inside the reader, where a book_id lets the response refresh the open reader.
# Always acts on Current.user; no user id is ever read from params.
class ReadingSettingsController < ApplicationController
  before_action :set_user

  def edit
  end

  def update
    @book = Book.find_visible_cached!(params[:book_id], user: @user) if params[:book_id].present?

    if @user.update_reading_settings(settings_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: home_path, notice: "Reading settings saved." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :update, status: :unprocessable_content }
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  private
    def set_user
      @user = Current.user
    end

    def settings_params
      params.require(:reading_settings).permit(:reader_page_animation, :reader_theme, :reader_text_size)
    end
end
