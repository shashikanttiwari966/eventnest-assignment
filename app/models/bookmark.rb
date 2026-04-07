class Bookmark < ApplicationRecord
	belongs_to :user
  belongs_to :event

  validates :user_id, uniqueness: { scope: :event_id, message: "already bookmarked this event" }
  
  # Authorization: Only attendees can bookmark
  validate :user_must_be_attendee

  private

  def user_must_be_attendee
    errors.add(:user, "must be an attendee to bookmark events") unless user&.role == "attendee"
  end
end
