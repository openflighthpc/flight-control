require_relative '../models/aws_project'
require_relative '../models/instance_log'
require_relative 'aws_sdk_error'
require_relative 'request_generator'
require 'aws-sdk-ec2'
require 'json'

class InstanceManager
  def initialize(project)
    @project = project
  end

  #Start or stop the chosen instance(s) by id. Creds hash must contain "provider" field, any others are optional required fields for the provider (e.g. AWS region)
  def update_instance_statuses(action, creds, instance_ids, verbose=false)
    instance_ids.each do |instance_id|
      response = http_request(uri: 'http://0.0.0.0:4567/providers/#{creds["provider"]}/get-instance-costs',
                              headers: {"Project-Credentials" => creds.inspect},
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
