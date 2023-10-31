require_relative '../models/aws_project'
require_relative '../models/instance_log'
require_relative 'aws_sdk_error'
require 'aws-sdk-ec2'

class InstanceManager
  def initialize(project)
    @project = project
  end

  #Start or stop the chosen instance(s) by id. Creds hash must contain "provider" field, everything else is optional required fields for the provider (e.g. AWS region)
  def update_instance_statuses(action, creds, instance_ids, verbose=false)
    #curl "/providers/#{creds['provider']}/start-instance
  end
end
