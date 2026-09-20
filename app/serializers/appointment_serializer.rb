class AppointmentSerializer
  def initialize(appointment)
    @appointment = appointment
  end

  def as_json(*)
    {
      id: appointment.id,
      start_at: appointment.start_at,
      name: appointment.name,
      email: appointment.email,
      phone: appointment.phone,
      reason: appointment.note,
      created_at: appointment.created_at
    }
  end

  private

  attr_reader :appointment
end
