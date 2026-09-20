class Appointment < ApplicationRecord
  include Slottable

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, length: { maximum: 100 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, length: { maximum: 20 }
  validates :note, length: { maximum: 200 }
end
