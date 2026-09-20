require "rails_helper"

RSpec.describe Availability do
  def slots(**args)
    described_class.new(**args).call
  end

  describe "#call" do
    it "returns every slot in an inclusive weekday range" do
      result = slots(from: "2026-09-21", to: "2026-09-25")

      expect(result.size).to eq(80)
      expect(result.first[:start_time]).to eq(Time.zone.local(2026, 9, 21, 9, 0))
      expect(result.last[:start_time]).to eq(Time.zone.local(2026, 9, 25, 16, 30))
      expect(result).to all(include(available: true))
    end

    it "returns Time objects with an available flag" do
      slot = slots(from: "2026-09-21", to: "2026-09-21").first

      expect(slot[:start_time]).to be_a(ActiveSupport::TimeWithZone)
      expect(slot.keys).to eq(%i[start_time available])
    end

    it "marks a booked slot unavailable" do
      create(:appointment, start_at: Time.zone.local(2026, 9, 21, 9, 30))

      result = slots(from: "2026-09-21", to: "2026-09-21")

      expect(result[1]).to include(available: false)
      expect(result[0]).to include(available: true)
    end

    it "frees the slot of a cancelled booking" do
      create(:appointment, :cancelled, start_at: Time.zone.local(2026, 9, 21, 9, 30))

      expect(slots(from: "2026-09-21", to: "2026-09-21")[1]).to include(available: true)
    end

    it "marks slots in the past unavailable" do
      result = slots(from: "2026-09-18", to: "2026-09-18") # last Friday

      expect(result.size).to eq(16)
      expect(result).to all(include(available: false))
    end

    it "gives weekend days no slots" do
      expect(slots(from: "2026-09-26", to: "2026-09-27")).to be_empty
      expect(slots(from: "2026-09-25", to: "2026-09-28").size).to eq(32) # Fri + Mon
    end
  end

  describe "range resolution" do
    it "defaults to the current Monday-to-Friday week" do
      result = slots

      expect(result.first[:start_time]).to eq(Time.zone.local(2026, 9, 14, 9, 0))
      expect(result.last[:start_time]).to eq(Time.zone.local(2026, 9, 18, 16, 30))
    end

    it "ends one month after the start when only the start is given" do
      result = slots(from: "2026-09-21")

      expect(result.first[:start_time].to_date).to eq(Date.new(2026, 9, 21))
      expect(result.last[:start_time].to_date).to eq(Date.new(2026, 10, 21))
    end

    it "starts one month before the end when only the end is given" do
      result = slots(to: "2026-10-21")

      expect(result.first[:start_time].to_date).to eq(Date.new(2026, 9, 21))
      expect(result.last[:start_time].to_date).to eq(Date.new(2026, 10, 21))
    end

    it "allows a range of exactly one month" do
      expect { slots(from: "2026-07-01", to: "2026-08-01") }.not_to raise_error
    end

    it "rejects a range longer than one month" do
      expect { slots(from: "2026-07-01", to: "2026-08-02") }
        .to raise_error(Availability::InvalidRange, "The range must not exceed one month.")
    end

    it "rejects an end before the start" do
      expect { slots(from: "2026-09-25", to: "2026-09-21") }
        .to raise_error(Availability::InvalidRange, "end must not be before start.")
    end

    it "rejects malformed dates, naming the parameter" do
      expect { slots(from: "soon", to: "2026-09-21") }
        .to raise_error(Availability::InvalidRange, "start must be a date in YYYY-MM-DD format.")
      expect { slots(from: "2026-09-21", to: "21/09/2026") }
        .to raise_error(Availability::InvalidRange, "end must be a date in YYYY-MM-DD format.")
    end
  end

  it "raises an ArgumentError subclass" do
    expect(Availability::InvalidRange).to be < ArgumentError
  end
end
