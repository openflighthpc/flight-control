namespace :instance_details do
  desc "Record instance prices and sizes for all platforms"
  task :record => :environment do |task, args|
    azure = AzureProject.active.first
    if azure
      RecordInstanceDetailsJob.perform_later(azure.id)
    else
      puts "No active azure project to record instance details with"
    end
    aws = AwsProject.active.first
    if aws
      RecordInstanceDetailsJob.perform_later(aws.id)
    else
      puts "No active azure project to record instance details with"
    end
  end
end
