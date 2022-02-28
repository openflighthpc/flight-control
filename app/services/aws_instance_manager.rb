require_relative '../models/aws_project'
require_relative '../models/instance_log'
require_relative 'aws_sdk_error'
require 'aws-sdk-ec2'

class AwsInstanceManager
  def initialize(project)
    @project = project
  end

  def update_instance_statuses(action, region, instance_ids, verbose=false)
    begin
      ec2 = Aws::EC2::Client.new(access_key_id: @project.access_key_ident, secret_access_key: @project.key, region: region)
      if action.to_s == "on"
        ec2.start_instances(instance_ids: instance_ids)
      else
        ec2.stop_instances(instance_ids: instance_ids)
      end
    rescue Aws::EC2::Errors::ServiceError, Seahorse::Client::NetworkingError => error
      raise AwsSdkError.new("Unable to change instance statuses for project #{@project.name} in region #{region}. #{error if @verbose}")
    rescue Aws::Errors::MissingRegionError => error
      raise AwsSdkError.new("Unable to change instance statuses for project #{@project.name} due to missing region. #{error if @verbose}")  
    end
  end
end
