require 'httparty'
require_relative '../models/project'
require_relative '../models/funds_transfer_request'

# This should just handle the communication, not the calcs of what to do or when
# It should probably handle recording audit logs (?)
# Easier to then replace/update this with some different mechanism if needed,
# e.g message queues
class FlightHubCommunicator

  def initialize(project)
    @project = project
  end

  def check_balance
    begin
      response = HTTParty.get(
        "#{department_path}/budget",
        headers: headers
      )
      if response.success?
        response["data"]["attributes"]["compute_unit_balance"]
      else
        msg = "Unable to query Hub dept balance for project #{@project.name}: #{response.body}"
        raise FlightHubApiError.new(msg)
      end
    rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EPIPE => error
      raise FlightHubApiError.new("Unable to connect to flight hub: #{error}")
    end
  end

  def move_funds(amount, action, reference_text, reference_url=nil)
    # This is a bit confusing: if I 'send' a negative amount, that's how much I receive.
    # Would be clearer if one endpoint for sending to hub, and one for receiving from hub.
    if action == "receive"
      adjusted_amount = amount.abs * -1
    elsif action == "send"
      adjusted_amount = amount.abs
    else
      raise ArgumentError.new("Invalid action")
    end
    record = create_funds_transfer_request(amount, action, reference_text)
    if record.save
      begin
        reference_id = "Control: #{record.id}"
        response = HTTParty.post(
          "#{department_path}/funds",
          headers: headers,
          body: transfer_request_body(adjusted_amount, reference_text, reference_id, reference_url)
        )
        if response.success?
          record.status = "completed"
          record.save
        else
          record.status = "failed"
          record.request_errors = parse_response_errors(response.parsed_response)
          record.save
        end
      rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EPIPE, EOFError => error
        error_message = "Unable to connect to flight hub: #{error}"
        record.status = "failed"
        record.request_errors = error_message
        record.save
      rescue => error
        record.status = "failed"
        record.request_errors = "Unable to complete request: #{error}"
        record.save
      end
    end
    record
  end

  private

  def create_funds_transfer_request(amount, action, reason)
    FundsTransferRequest.new(
      amount: amount, action: action,
      reason: reason, project_id: @project.id
    )
  end

  def department_path
    raise FlightHubApiError.new("Project has no flight hub id") if @project.flight_hub_id.nil?

    "#{flight_hub_path}/departments/#{@project.flight_hub_id}"
  end

  def flight_hub_path
    Rails.configuration.flight_hub_url
  end

  def headers
    {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "Authorization" => "Bearer #{jwt}",
    }
  end

  def jwt
    JsonWebToken.encode(
      {
        sub: 'Alces Flight Control',
        iss: 'Alces Flight Control',
        aud: 'Flight Hub',
      },
      5.minutes.from_now
    )
  end

  # Reference id could be "control: #{}" with id that of an associated
  # transfer request record
  def transfer_request_body(amount, reference_text, reference_id, reference_url)
    {}.tap do |h| 
      h[:amount] =  amount
      h[:currency] = "compute unit"
      h[:code] = "control"
      h[:reference_text] = reference_text
      h[:reference_id] = reference_id
      h[:reference_url] = reference_url if reference_url
      h[:effective_at] = Date.current
    end.to_json
  end

  # Would be easier if hub gave a more consistent
  # format, instead of sometimes a hash, sometimes a string.
  # If something goes very wrong, sometimes returns html.
  def parse_response_errors(response)
    return message.truncate(120)  if response.is_a?(String)

    message = ""
    response.each do |attribute, errors|
      message << "#{attribute}: #{errors.join("; ")}\n"
    end
    message
  end
end

class FlightHubApiError < StandardError
  attr_accessor :error_messages
  def initialize(msg)
    @error_messages = []
    super(msg)
  end
end
