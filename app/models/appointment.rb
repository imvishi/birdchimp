class Appointment < ApplicationRecord
  include Slottable

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, length: { maximum: 100 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, length: { maximum: 20 }
  validates :note, length: { maximum: 200 }


  scope :active, -> { where(cancelled_at: nil) }
  scope :upcoming, -> { where(start_at: Time.current..) }

  def cancel!
    update!(cancelled_at: Time.current)
  end
end
