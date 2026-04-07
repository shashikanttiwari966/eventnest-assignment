module Api
  module V1
    class EventsController < ApplicationController
      skip_before_action :authenticate_user!, only: [:index, :show]
      before_action :find_event, only: [:update, :destroy]

      def index
        # BUG FIX #5 — N+1 Query
        # Without .includes(), every iteration of the render loop below fires
        events = Event.published.upcoming.includes(:user, :ticket_tiers)

        if params[:search].present?
          # BUG FIX #1 — SQL Injection (CRITICAL)
          # FIX: Use parameterized query to prevent SQL injection.
          # Previously: events.where("title LIKE '%#{params[:search]}%'")
          # That allowed attackers to inject arbitrary SQL via the search param.
          search_term = "%#{params[:search]}%"
          events = events.where(
            "title LIKE :search OR description LIKE :search",
            search: search_term
          )
        end

        if params[:category].present?
          events = events.where(category: params[:category])
        end

        if params[:city].present?
          events = events.where(city: params[:city])
        end

        # BUG FIX #1 (continued) — ORDER BY Injection
        # FIX: Whitelist sort_by column to prevent SQL injection via order clause.
        allowed_sort = %w[starts_at ends_at title created_at]
        sort_column = allowed_sort.include?(params[:sort_by]) ? params[:sort_by] : "starts_at"
        events = events.order("#{sort_column} ASC")

        render json: events.map { |event|
          {
            id: event.id,
            title: event.title,
            description: event.description,
            venue: event.venue,
            city: event.city,
            starts_at: event.starts_at,
            ends_at: event.ends_at,
            category: event.category,
            organizer: event.user.name,
            total_tickets: event.total_tickets,
            tickets_sold: event.total_sold,
            ticket_tiers: event.ticket_tiers.map { |t|
              {
                id: t.id,
                name: t.name,
                price: t.price.to_f,
                available: t.available_quantity
              }
            }
          }
        }
      end

      def show
        event = Event.find_by(id: params[:id])
        return render json: { error: "Event not found" }, status: :not_found if event.nil?

        # 1. Define the base data hash first
        event_data = {
          id: event.id,
          title: event.title,
          description: event.description,
          venue: event.venue,
          city: event.city,
          starts_at: event.starts_at,
          ends_at: event.ends_at,
          status: event.status,
          category: event.category,
          organizer: {
            id: event.user.id,
            name: event.user.name
          },
          ticket_tiers: event.ticket_tiers.map do |t|
            {
              id: t.id,
              name: t.name,
              price: t.price.to_f,
              quantity: t.quantity,
              sold: t.sold_count,
              available: t.available_quantity
            }
          end
        }

        # 2. Add the bookmark count ONLY if the user is the authorized organizer
        # Task 3 Requirement: "only organizers see counts"
        if current_user&.role == "organizer" && event.user_id == current_user.id
          event_data[:bookmarks_count] = event.bookmarks.count
        end

        render json: event_data
      end

      def create
        # Fix: Add role and ownership guards
        authorize_organizer!

        event = Event.new(event_params)
        event.user = current_user

        if event.save
          render json: event, status: :created
        else
          render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @event.update(event_params)
          render json: @event
        else
          render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @event.destroy
        render json: { message: "Event was successfully deleted." }, status: :ok
      end

      private

      def event_params
        params.require(:event).permit(:title, :description, :venue, :city,
          :starts_at, :ends_at, :category, :max_capacity, :status)
      end

      def authorize_organizer!
        render json: { error: "Forbidden" }, status: :forbidden unless current_user.organizer?
      end

      # Fix: Scope all event queries through current_user.events
      def find_event
        @event = current_user&.events&.find_by(id: params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Event not found"}, status: :not_found
      end
    end
  end
end
