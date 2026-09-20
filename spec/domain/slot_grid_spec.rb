require "rails_helper"

RSpec.describe SlotGrid do
  let(:tuesday) { Date.new(2026, 9, 22) }
  let(:saturday) { Date.new(2026, 9, 26) }
  let(:sunday) { Date.new(2026, 9, 27) }

  def at(hour, min, sec = 0)
    tuesday.in_time_zone.change(hour: hour, min: min, sec: sec)
  end

  describe ".on" do
    subject(:slots) { described_class.on(tuesday) }

    it "has 16 slots from 9:00 to 16:30, 30 minutes apart" do
      expect(slots.size).to eq(16)
      expect(slots.size).to eq(SlotGrid::PER_DAY)
      expect(slots.first).to eq(Time.zone.local(2026, 9, 22, 9, 0))
      expect(slots.last).to eq(Time.zone.local(2026, 9, 22, 16, 30))
      expect(slots.each_cons(2)).to all(satisfy { |a, b| b - a == 30.minutes })
    end

    it "returns times in the app time zone" do
      expect(slots.first.zone).to eq("IST")
    end

    it "is empty on weekends" do
      expect(described_class.on(saturday)).to be_empty
      expect(described_class.on(sunday)).to be_empty
    end
  end

  describe ".include?" do
    it "accepts the first and last slots of the day" do
      expect(described_class.include?(at(9, 0))).to be(true)
      expect(described_class.include?(at(16, 30))).to be(true)
    end

    it "rejects times outside business hours" do
      expect(described_class.include?(at(8, 30))).to be(false)
      expect(described_class.include?(at(17, 0))).to be(false)
    end

    it "rejects times off the half-hour grid" do
      expect(described_class.include?(at(10, 15))).to be(false)
      expect(described_class.include?(at(10, 30, 1))).to be(false)
    end

    it "rejects weekends" do
      expect(described_class.include?(saturday.in_time_zone.change(hour: 10))).to be(false)
      expect(described_class.include?(sunday.in_time_zone.change(hour: 10))).to be(false)
    end

    it "judges a time by its wall clock in the app time zone" do
      expect(described_class.include?(Time.utc(2026, 9, 22, 3, 30).in_time_zone)).to be(true)   # 09:00 IST
      expect(described_class.include?(Time.utc(2026, 9, 22, 9, 0).in_time_zone)).to be(true)    # 14:30 IST
      expect(described_class.include?(Time.utc(2026, 9, 22, 12, 0).in_time_zone)).to be(false)  # 17:30 IST
    end
  end
end
