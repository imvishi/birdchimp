require "rails_helper"

# Exercised on a minimal model so the rules are tested independently of Appointment.
RSpec.describe Slottable do
  let(:booking_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include Slottable

      attribute :start_at, :datetime

      def self.name = "Booking"
    end
  end

  def errors_for(start_at)
    booking_class.new(start_at: start_at).tap(&:validate).errors[:start_at]
  end

  describe "presence of start_at" do
    it "rejects a blank start_at" do
      expect(errors_for(nil)).to include("can't be blank")
    end

    it "accepts a present start_at" do
      expect(errors_for(Time.zone.local(2026, 9, 21, 9, 0))).not_to include("can't be blank")
    end
  end

  describe "start_at must be in the future" do
    let(:message) { "must be in the future" }

    it "rejects a slot that has already passed" do
      expect(errors_for(Time.zone.local(2026, 9, 18, 10, 0))).to include(message) # last Friday
    end

    it "rejects the current instant" do
      expect(errors_for(Time.current)).to include(message)
    end

    it "accepts a slot later today or on a later day" do
      expect(errors_for(Time.zone.local(2026, 9, 21, 9, 0))).not_to include(message)
    end
  end

  describe "start_at must be on the slot grid" do
    let(:message) { "must be a 30 minute slot between 9:00 AM and 4:30 PM, Monday to Friday" }

    it "accepts the first and last slots of a weekday" do
      expect(errors_for(Time.zone.local(2026, 9, 21, 9, 0))).not_to include(message)
      expect(errors_for(Time.zone.local(2026, 9, 25, 16, 30))).not_to include(message)
    end

    it "rejects a time before opening" do
      expect(errors_for(Time.zone.local(2026, 9, 21, 8, 30))).to include(message)
    end

    it "rejects a time at or after closing" do
      expect(errors_for(Time.zone.local(2026, 9, 21, 17, 0))).to include(message)
    end

    it "rejects a time off the half-hour grid" do
      expect(errors_for(Time.zone.local(2026, 9, 21, 10, 15))).to include(message)
    end

    it "rejects a time with seconds" do
      expect(errors_for(Time.zone.local(2026, 9, 21, 10, 30, 1))).to include(message)
    end

    it "rejects weekends" do
      expect(errors_for(Time.zone.local(2026, 9, 26, 10, 0))).to include(message) # Saturday
      expect(errors_for(Time.zone.local(2026, 9, 27, 10, 0))).to include(message) # Sunday
    end
  end

  it "is valid when every rule passes" do
    expect(booking_class.new(start_at: Time.zone.local(2026, 9, 21, 9, 0))).to be_valid
  end
end
