module Api
  class AppointmentsController < BaseController
    include Pagy::Method

    PAGE_SIZE = 20
    MAX_PAGE_SIZE = 100

    rescue_from Availability::InvalidRange do |error|
      render_error :invalid_request, error.message, status: :bad_request
    end

    # GET /api/appointments?limit=20&cursor=<next_cursor from the previous page>
    def index
      pagy, appointments = pagy(:keyset, Appointment.active.order(:start_at, :id),
                                page_key: "cursor", limit: PAGE_SIZE, max_limit: MAX_PAGE_SIZE)

      render json: {
        appointments: appointments.map { |appointment| AppointmentSerializer.new(appointment) },
        next_cursor: pagy.next
      }
    end

    # GET /api/appointments/available?start=YYYY-MM-DD&end=YYYY-MM-DD
    def available
      slots = Availability.new(from: params[:start], to: params[:end]).call
      render json: { slots: slots }
    end

    # POST /api/appointments
    def create
      appointment = Appointment.new(appointment_params)

      if appointment.save
        render json: AppointmentSerializer.new(appointment), status: :created
      else
        render_error :validation_failed,
                     appointment.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # DELETE /api/appointments/:id
    def destroy
      appointment = Appointment.active.find(params[:id])
      appointment.cancel!
      render json: AppointmentSerializer.new(appointment)
    end

    private

    def appointment_params
      params.require(:appointment).permit(:start_at, :name, :email, :phone, :note)
    end

  end
end
