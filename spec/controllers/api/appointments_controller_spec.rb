require "rails_helper"

RSpec.describe Api::AppointmentsController, type: :request do
  let(:slot) { "2026-09-21T09:30:00+05:30" } # Monday

  # A method, not a let: examples make several requests and read each response.
  def json
    response.parsed_body
  end

  def post_appointment(**attrs)
    defaults = { start_at: slot, name: "Vishal", email: "ruby@example.com", phone: "+91 98765 43210", note: "Pickup schedule" }
    post api_appointments_path, params: { appointment: defaults.merge(attrs) }, as: :json
  end

  describe "GET /api/appointments" do
    it "lists active appointments chronologically in the serialized shape" do
      later = create(:appointment, start_at: Time.zone.local(2026, 9, 22, 10, 0))
      first = create(:appointment, start_at: Time.zone.local(2026, 9, 21, 9, 0))
      create(:appointment, :cancelled, start_at: Time.zone.local(2026, 9, 21, 9, 30))

      get api_appointments_path

      expect(response).to have_http_status(:ok)
      expect(json["appointments"].map { |a| a["id"] }).to eq([first.id, later.id])
      expect(json["appointments"].first.keys).to eq(%w[id start_at name email phone reason created_at])
      expect(json["next_cursor"]).to be_nil
    end

    it "paginates with a cursor" do
      3.times { |i| create(:appointment, name: "P#{i}", start_at: Time.zone.local(2026, 9, 21, 9, 0) + i * 30.minutes) }

      get api_appointments_path, params: { limit: 2 }
      page1 = json
      expect(page1["appointments"].map { |a| a["name"] }).to eq(%w[P0 P1])
      expect(page1["next_cursor"]).to be_present

      get api_appointments_path, params: { limit: 2, cursor: page1["next_cursor"] }
      expect(json["appointments"].map { |a| a["name"] }).to eq(%w[P2])
      expect(json["next_cursor"]).to be_nil
    end

    it "hides appointments whose slot has passed when upcoming=true" do
      past = create(:appointment, :past)
      future = create(:appointment, start_at: Time.zone.local(2026, 9, 21, 9, 0))

      get api_appointments_path
      expect(json["appointments"].map { |a| a["id"] }).to eq([past.id, future.id])

      get api_appointments_path, params: { upcoming: true }
      expect(json["appointments"].map { |a| a["id"] }).to eq([future.id])
    end
  end

  describe "GET /api/appointments/available" do
    it "returns each slot in the range with an availability flag" do
      create(:appointment, start_at: Time.zone.local(2026, 9, 21, 9, 30))

      get available_api_appointments_path, params: { start: "2026-09-21", end: "2026-09-25" }

      expect(response).to have_http_status(:ok)
      expect(json["slots"].size).to eq(80)
      expect(Time.zone.parse(json["slots"][0]["start_time"])).to eq(Time.zone.local(2026, 9, 21, 9, 0))
      expect(json["slots"][0]["available"]).to be(true)
      expect(json["slots"][1]["available"]).to be(false)
    end

    it "defaults to the current week" do
      get available_api_appointments_path

      expect(response).to have_http_status(:ok)
      expect(json["slots"].size).to eq(80)
      expect(json["slots"].first["start_time"]).to start_with("2026-09-14")
    end

    it "rejects an end before the start with 400" do
      get available_api_appointments_path, params: { start: "2026-09-25", end: "2026-09-21" }

      expect(response).to have_http_status(:bad_request)
      expect(json).to eq("error" => "invalid_request", "message" => "end must not be before start.")
    end

    it "rejects a malformed date with 400" do
      get available_api_appointments_path, params: { start: "soon" }

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to eq("invalid_request")
    end
  end

  describe "POST /api/appointments" do
    it "books a slot and returns the appointment" do
      expect { post_appointment }.to change(Appointment, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to include("name" => "Vishal", "email" => "ruby@example.com",
                              "phone" => "+91 98765 43210", "reason" => "Pickup schedule")
      expect(Time.zone.parse(json["start_at"])).to eq(Time.zone.parse(slot))
      expect(json["id"]).to be_an(Integer)
      expect(json["created_at"]).to be_present
    end

    it "ignores unknown attributes" do
      post_appointment(cancelled_at: Time.current.iso8601, admin: true)

      expect(response).to have_http_status(:created)
      expect(Appointment.last.cancelled_at).to be_nil
    end

    it "returns 422 for a time that is not a slot" do
      expect { post_appointment(start_at: "2026-09-21T17:00:00+05:30") }.not_to change(Appointment, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to eq("validation_failed")
      expect(json["message"]).to match(/must be a 30 minute slot/)
    end

    it "returns 422 for a slot in the past" do
      post_appointment(start_at: "2026-09-18T10:00:00+05:30")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["message"]).to match(/must be in the future/)
    end

    it "returns 422 for missing details" do
      post_appointment(name: "", email: "nope")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["message"]).to match(/Name can't be blank/).and match(/Email is invalid/)
    end

    it "returns 409 when the slot is already booked" do
      create(:appointment, start_at: slot)

      expect { post_appointment }.not_to change(Appointment, :count)

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq("conflict")
    end

    it "allows a slot whose earlier booking was cancelled" do
      create(:appointment, :cancelled, start_at: slot)

      post_appointment

      expect(response).to have_http_status(:created)
    end
  end

  describe "DELETE /api/appointments/:id" do
    it "cancels the appointment" do
      appointment = create(:appointment, start_at: slot)

      delete api_appointment_path(appointment)

      expect(response).to have_http_status(:ok)
      expect(json["id"]).to eq(appointment.id)
      expect(appointment.reload.cancelled_at).to be_present
    end

    it "returns 404 for an unknown id" do
      delete api_appointment_path(999_999)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an already cancelled appointment" do
      appointment = create(:appointment, :cancelled, start_at: slot)

      delete api_appointment_path(appointment)

      expect(response).to have_http_status(:not_found)
    end
  end
end
