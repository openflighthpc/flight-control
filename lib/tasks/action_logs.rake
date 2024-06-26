require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/action_log"

namespace :action_logs do
  desc "Add an action log"
  task :add, [:project, :action, :reason, :instance_id, :actioned_at] => :environment do |task, args|
    project = Project.find_by(name: args[:project])
    if !project
      puts "No project found with that name"
      exit
    end

    instance_id = args[:instance_id]
    if args[:actioned_at]
      begin
        actioned_at = Time.parse(args[:actioned_at])
        puts actioned_at
      rescue ArgumentError
        puts "Invalid time"
        exit
      end
    else
      actioned_at = Time.current
    end

    action_log = ActionLog.new(project_id: project.id, action: args[:action], reason: args[:reason],
                                instance_id: instance_id, automated: true,
                                actioned_at: actioned_at)
    if !action_log.valid?
      puts action_log.errors.full_messages   
    else
      action_log.save!
    end
  end
end
