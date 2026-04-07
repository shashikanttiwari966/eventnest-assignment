class TicketTier < ApplicationRecord
  belongs_to :event
  has_many :order_items

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }

  def available_quantity
    quantity - sold_count
  end

  def sold_out?
    sold_count >= quantity
  end

  def reserve_tickets!(count)
    # Fix: Use with_lock to acquire a row-level exclusive lock for the duration of the check-and-update
    with_lock do
      if available_quantity >= count
        update_columns(sold_count: sold_count + count)
      else
        raise "Not enough tickets available"
      end
    end
  end
end
