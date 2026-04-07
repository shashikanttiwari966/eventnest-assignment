require "rails_helper"

RSpec.describe Api::V1::BookmarksController, type: :request do
  let(:attendee) { create(:user, role: "attendee") }
  let(:organizer) { create(:user, role: "organizer") }
  let(:event) { create(:event, user: organizer) }

  def auth_headers(user)
    token = user.generate_jwt
    { "Authorization" => "Bearer #{token}" }
  end

  describe "POST /api/v1/bookmarks" do
    context "when user is an attendee" do
      it "bookmarks an event successfully" do
        post "/api/v1/bookmarks", 
             params: { event_id: event.id }, 
             headers: auth_headers(attendee)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["message"]).to eq("Event bookmarked successfully")
      end

      it "rejects duplicate bookmarks (Database Uniqueness)" do
        create(:bookmark, user: attendee, event: event)
        
        post "/api/v1/bookmarks", 
             params: { event_id: event.id }, 
             headers: auth_headers(attendee)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"]).to include("User already bookmarked this event")
      end
    end

    context "when user is an organizer" do
      it "returns 422 because only attendees can bookmark" do
        post "/api/v1/bookmarks", 
             params: { event_id: event.id }, 
             headers: auth_headers(organizer)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /api/v1/bookmarks" do
    it "returns list of bookmarked events for the attendee" do
      create(:bookmark, user: attendee, event: event)
      
      get "/api/v1/bookmarks", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data.length).to eq(1)
      expect(data.first["id"]).to eq(event.id)
    end
  end

  describe "DELETE /api/v1/bookmarks/:id" do
    it "removes a bookmark" do
      create(:bookmark, user: attendee, event: event)

      delete "/api/v1/bookmarks/#{event.id}", headers: auth_headers(attendee)

      expect(response).to have_http_status(:ok)
      expect(Bookmark.count).to eq(0)
    end
  end
end