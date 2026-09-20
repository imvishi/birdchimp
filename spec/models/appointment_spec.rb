require "rails_helper"

RSpec.describe Appointment do
  let(:slot) { Time.zone.local(2026, 9, 21, 9, 30) } # Monday

  describe "validations" do
    it "is valid with a name, email and a future slot" do
      expect(build(:appointment)).to be_valid
    end

    it "requires a name of at most 100 characters" do
      expect(build(:appointment, name: "")).not_to be_valid
      expect(build(:appointment, name: "a" * 101)).not_to be_valid
      expect(build(:appointment, name: "a" * 100)).to be_valid
    end

    it "requires a well-formed email of at most 100 characters" do
      expect(build(:appointment, email: "")).not_to be_valid
      expect(build(:appointment, email: "not-an-email")).not_to be_valid
      expect(build(:appointment, email: "#{"a" * 95}@x.com")).not_to be_valid
      expect(build(:appointment, email: "ada@example.com")).to be_valid
    end

    it "treats phone and note as optional but bounded" do
      expect(build(:appointment, phone: nil, note: nil)).to be_valid
      expect(build(:appointment, phone: "1" * 21)).not_to be_valid
      expect(build(:appointment, note: "n" * 201)).not_to be_valid
    end

    it "includes the slot rules" do
      expect(build(:appointment, start_at: Time.zone.local(2026, 9, 21, 17, 0))).not_to be_valid
      expect(build(:appointment, start_at: Time.zone.local(2026, 9, 18, 10, 0))).not_to be_valid # past
    end
  end

  describe "#cancel!" do
    it "stamps cancelled_at and removes the appointment from active" do
      appointment = create(:appointment)

      appointment.cancel!

      expect(appointment.cancelled_at).to be_present
      expect(described_class.active).not_to include(appointment)
    end
  end

  describe ".active" do
    it "excludes cancelled appointments" do
      kept = create(:appointment, start_at: slot)
      create(:appointment, :cancelled, start_at: slot + 30.minutes)

      expect(described_class.active).to contain_exactly(kept)
    end
  end

  describe ".upcoming" do
    it "excludes appointments whose slot has passed" do
      create(:appointment, :past)
      future = create(:appointment)

      expect(described_class.upcoming).to contain_exactly(future)
    end
  end

  describe "slot uniqueness (database index)" do
    it "refuses two active appointments in the same slot" do
      create(:appointment, start_at: slot)

      expect { create(:appointment, start_at: slot) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "frees the slot once the appointment is cancelled" do
      create(:appointment, :cancelled, start_at: slot)

      expect { create(:appointment, start_at: slot) }.not_to raise_error
    end
  end
end
