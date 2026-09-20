module Api
  class BaseController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound do |error|
      render_error :not_found, "#{error.model.to_s.underscore.humanize} not found.", status: :not_found
    end

    rescue_from ActiveRecord::RecordNotUnique do
      render_error :conflict, "A record with those details already exists.", status: :conflict
    end

    private

    def render_error(code, message, status:, details: nil)
      body = { error: code, message: message }
      body[:details] = details if details.present?
      render json: body, status: status
    end
  end
end
