require 'httparty'
require_relative '../models/project'

class FlightHubCommunicator

  def initialize(project)
    @project = project
  end

  def check_balance
    response = HTTParty.get(
      "#{flight_hub_path}/departments/#{@project.flight_hub_id}/budget",
      headers: headers
    )
    if response.success?
      response["data"]["attributes"]["compute_unit_balance"]
    else
      # error handling
    end
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
end
