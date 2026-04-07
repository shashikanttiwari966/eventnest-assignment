module Api
  module V1
    class BookmarksController < ApplicationController
      # List my bookmarks
      def index
        bookmarks = current_user.bookmarks.includes(:event)
        render json: bookmarks.map(&:event)
      end

      # Bookmark an event
      def create
        bookmark = current_user.bookmarks.build(event_id: params[:event_id])
        
        if bookmark.save
          render json: { message: "Event bookmarked successfully" }, status: :created
        else
          render json: { errors: bookmark.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Remove a bookmark
      def destroy
        bookmark = current_user.bookmarks.find_by(event_id: params[:id])
        if bookmark&.destroy
          render json: { message: "Bookmark removed" }, status: :ok
        else
          render json: { error: "Bookmark not found" }, status: :not_found
        end
      end
    end
  end
end