require_relative '../models/example_project'
require_relative '../models/instance_log'
require_relative 'example_api_error'
require_relative 'http_request'

class ExampleInstanceManager
  def initialize(project)
    @project = project
  end

  def update_instance_statuses(action, region, instance_ids, verbose=false)
    instance_ids.each do |instance_id|
      command = action.to_s == "on" ? "start-instance" : "stop-instance"
      uri = Rails.application.config.control_api_uri + "/providers/example-provider/#{command}"
      response = http_request(uri: uri,
                              request_type: "post",
                              headers: {'Project-Credentials' => {'PROJECT_NAME': @project.name}.to_json},
                              body: { "instance_id" => instance_id }.to_json
                             )
      raise ExampleApiError, response.body unless response.code == "200"
    end
  end
end
