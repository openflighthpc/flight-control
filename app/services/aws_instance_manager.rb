require_relative '../models/aws_project'
require_relative '../models/instance_log'
require_relative 'aws_sdk_error'
require 'aws-sdk-ec2'

class AwsInstanceManager
  def initialize(project)
    @project = project
  end

  def update_instance_statuses(action, region, instance_ids, verbose=false)
    instance_ids.each do |instance_id|
      command = action == "on" ? "start-instance" : "stop-instance"
      response = http_request(uri: 'http://0.0.0.0:4567/providers/aws/#{command}',
                              headers: {"Project-Credentials" => {"region": region}.inspect},
                              body: { "instance_id" => instance_id }.to_json
                             )
      case response.code
      when 200
        #Instance state set successfully
      when 401
        raise 'Credentials missing or incorrect'
      when 404
        raise 'Provider #{creds["provider"]} and/or instance #{instance_id} not found'
      when 500
        raise 'Internal error in Control API'
      end
    end
  end
end
