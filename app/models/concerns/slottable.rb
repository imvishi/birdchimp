# Appointments can only start on a 30 minute slot (9:00, 9:30, 10:00 ...)
# between 9:00 AM and 4:30 PM, Monday to Friday.
module Slottable
  extend ActiveSupport::Concern

  included do
    validates :start_time, presence: true
    validate :start_time_is_a_slot
  end

  private

  def start_time_is_a_slot
    return if start_time.blank?

    weekday = start_time.on_weekday?
    on_half_hour = [0, 30].include?(start_time.min) && start_time.sec.zero?
    within_hours = start_time.seconds_since_midnight.between?(9.hours, 16.hours + 30.minutes)

    return if weekday && on_half_hour && within_hours

    errors.add(:start_time, "must be a 30 minute slot between 9:00 AM and 4:30 PM, Monday to Friday")
  end
end
