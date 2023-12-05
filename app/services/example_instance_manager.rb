require_relative '../models/example_project'
require_relative '../models/instance_log'
require_relative 'example_errors'
require_relative 'request_generator'

class ExampleInstanceManager
  def initialize(project)
    @project = project
  end

  def update_instance_statuses(action, region, instance_ids, verbose=false)
    instance_ids.each do |instance_id|
      command = action == "on" ? "start-instance" : "stop-instance"
      response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/#{command}',
                              request_type: "post",
                              headers: {'Project-Credentials' => {'PROJECT_NAME': @project.name}.to_json},
                              body: { "instance_id" => instance_id }.to_json
                             )
      case response.code
      when 200
        #Instance state set successfully
      when 401
        raise ExampleApiError 'Credentials missing or incorrect'
      when 404
        raise ExampleApiError 'Instance #{instance_id} not found'
      when 500
        raise ExampleApiError 'Internal error in Control API'
      end
    end
  end
end
