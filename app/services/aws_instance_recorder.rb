require_relative '../models/aws_project'
require_relative '../models/instance_log'
require_relative 'aws_sdk_error'
require 'aws-sdk-ec2'

class AwsInstanceRecorder

  def initialize(project)
    @project = project
  end

  def record_logs(rerun=false, verbose=true)
    today_logs = @project.instance_logs.where(date: Date.current)
    any_nodes = false
    log_recorded = false
    if !today_logs.any? || rerun
      log_ids = []
      @project.regions.each do |region|
        begin
          instances_checker = Aws::EC2::Client.new(access_key_id: @project.access_key_ident, secret_access_key: @project.key, region: region)
          results = instances_checker.describe_instances(project_instances_query)
        rescue Aws::EC2::Errors::ServiceError, Seahorse::Client::NetworkingError => error
          raise AwsSdkError.new("Unable to determine AWS instances for project #{@project.name} in region #{region}. #{error if @verbose}")
        rescue Aws::Errors::MissingRegionError => error
          raise AwsSdkError.new("Unable to determine AWS instances for project #{@project.name} due to missing region. #{error if @verbose}")  
        end
        results.reservations.each do |reservation|
          any_nodes = true if reservation.instances.any?
          reservation.instances.each do |instance|
            named = ""
            compute = false
            compute_group = nil
            instance.tags.each do |tag|
              if tag.key == "Name"
                named = tag.value
              end
              if tag.key == "type"
                compute = tag.value == "compute"
              end
              if tag.key == "compute_group"
                compute_group = tag.value
              end
            end
            status = instance.state.name

            log = today_logs.find_by(instance_id: instance.instance_id)
            if !log
              log = InstanceLog.create(
                instance_id: instance.instance_id,
                project_id: @project.id,
                instance_name: named,
                instance_type: instance.instance_type,
                compute_group: compute_group,
                status: status,
                platform: "aws",
                region: region,
                date: Date.current,
                last_checked: Time.now,
                last_status_change: Time.now
              )
            else
              log.status = status
              log.compute_group = compute_group # rare, but could have changed
              log.last_checked = Time.now
              log.save
            end
            log_recorded = true if log.valid? && log.persisted?
            log_ids << log.id
          end
        end
      end
      # If any instances have been deleted, ensure logs recorded as inactive.
      # Can't delete them as that may interfere with forecasts, action logs, etc.
      if log_ids.length != today_logs.count
        obsolete_logs = today_logs.where("id NOT IN (?)", log_ids.compact)
        obsolete_logs.update_all(status: "stopped")
      end
    end
    log_recorded ? "Logs recorded" : (any_nodes ? "Logs NOT recorded" : "No logs to record")
  end

  def validate_credentials
    valid = true
    begin
      instances_checker = Aws::EC2::Client.new(access_key_id: @project.access_key_ident,
                                               secret_access_key: @project.key,
                                               region: @project.regions.first)
      instances_checker.describe_instances(project_instances_query)
    rescue => error
      puts "Unable to obtain instance status data: #{error}"
      valid = false
    end
    valid
  end

  private

  def project_instances_query
    query = {
      filters: [
        {
          name: "tag:type",
          values: ["compute"]
        }
      ], 
    }
    query[:filters] << tag_filter if @project.filter_level == "tag"
    query
  end

  def tag_filter
    {
      name: "tag:project", 
      values: [@project.project_tag], 
    }
  end
end
