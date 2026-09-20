module SlotGrid
  LENGTH = 30.minutes
  FIRST_AT = 9.hours              # offset from midnight
  LAST_AT = 16.hours + 30.minutes
  PER_DAY = ((LAST_AT - FIRST_AT) / LENGTH).to_i + 1

  module_function

  # The slot start times on `date`; none on weekends.
  def on(date)
    return [] unless date.on_weekday?

    first = date.in_time_zone + FIRST_AT
    Array.new(PER_DAY) { |i| first + i * LENGTH }
  end

  # Is `time` exactly the start of a slot?
  def include?(time)
    since_midnight = time.seconds_since_midnight

    time.on_weekday? &&
      (since_midnight % LENGTH).zero? &&
      since_midnight.between?(FIRST_AT, LAST_AT)
  end
end
