module Slottable
  extend ActiveSupport::Concern

  included do
    validates :start_at, presence: true
    validates :start_at, comparison: { greater_than: -> { Time.current }, message: "must be in the future" }
    validate :start_at_is_a_slot
  end

  private

  def start_at_is_a_slot
    return if start_at.blank? || SlotGrid.include?(start_at)

    errors.add(:start_at, "must be a 30 minute slot between 9:00 AM and 4:30 PM, Monday to Friday")
  end
end
