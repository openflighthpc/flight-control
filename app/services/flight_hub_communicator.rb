require 'httparty'
require_relative '../models/project'

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
        puts response.body
      end
    rescue Errno::ECONNRESET, Errno::EPIPE => error
      raise FlightHubApiError.new("Unable to connect to flight hub: #{error}")
    end  
  end

  def move_funds(amount, action, reference_text, reference_id, reference_url=nil)
    # This is a bit confusing: if I 'send' a negative amount, that's how much I receive.
    # Would be clearer if one endpoint for sending to hub, and one for receiving from hub.
    if action == "receive"
      amount = amount.abs * -1
    elsif action = "send"
      amount = amount.abs
    else
      raise ArgumentError.new("Invalid action")
    end
    begin
      response = HTTParty.post(
        "#{department_path}/funds",
        headers: headers,
        body: transfer_request_body(amount, reference_text, reference_id, reference_url)
      )
      if response.success?
        true
      else
        puts response.body
      end
    rescue Errno::ECONNRESET, Errno::EPIPE => error
      raise FlightHubApiError.new("Unable to connect to flight hub: #{error}")
    end
  end

  def department_path
    "#{flight_hub_path}/departments/#{@project.flight_hub_id}"
  end

  def flight_hub_path
    Rails.configuration.flight_hub_url
  end

  def headers
    {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
    }
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
    end.to_json
  end
end

class FlightHubApiError < StandardError
  attr_accessor :error_messages
  def initialize(msg)
    @error_messages = []
    super(msg)
  end
end
