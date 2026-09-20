class Availability
  class InvalidRange < ArgumentError; end

  MAX_RANGE = 1.month

  def initialize(from: nil, to: nil)
    @from = from
    @to = to
  end

  def call
    start_date, end_date = resolve_range

    slot_times = (start_date..end_date).flat_map { |date| SlotGrid.on(date) }
    return [] if slot_times.empty?

    booked = Appointment.active.where(start_at: slot_times.first..slot_times.last).pluck(:start_at).map(&:to_i).to_set
    now = Time.current

    slot_times.map do |time|
      { start_time: time, available: time > now && !booked.include?(time.to_i) }
    end
  end

  private

  def resolve_range
    if @from.blank? && @to.blank?
      monday = Date.current.beginning_of_week
      return [monday, monday + 4]
    end

    start_date = parse_date(@from, "start") if @from.present?
    end_date = parse_date(@to, "end") if @to.present?
    start_date ||= end_date - MAX_RANGE
    end_date ||= start_date + MAX_RANGE

    raise InvalidRange, "end must not be before start." if end_date < start_date
    raise InvalidRange, "The range must not exceed one month." if end_date > start_date + MAX_RANGE

    [start_date, end_date]
  end

  def parse_date(value, name)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    raise InvalidRange, "#{name} must be a date in YYYY-MM-DD format."
  end
end
