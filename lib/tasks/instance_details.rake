require_relative "../../app/models/application_record"
require_relative "../../app/models/aws_project"
require_relative "../../app/models/azure_project"
require_relative "../../app/models/cost_log"

namespace :instance_details do
  desc "Record instance prices and sizes for all platforms"
  task :record => :environment do |task, args|
    azure = AzureProject.active.first
    if azure
      azure.record_instance_details
    else
      puts "No active Azure project to record instance details with"
    end
    aws = AwsProject.active.first
    if aws
      aws.record_instance_details
    else
      puts "No active AWS project to record instance details with"
    end
  end
end
