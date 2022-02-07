require_relative "../../app/models/application_record"
require_relative "../../app/models/project"
require_relative "../../app/models/action_log"

namespace :action_logs do
  desc "Add an action log"
  task :add, [:project, :action, :reason, :instance_id] => :environment do |task, args|
    project = Project.find_by(name: args[:project])
    return "No project found with that name" if !project

    instance_id = args[:instance_id]

    action_log = ActionLog.new(project_id: project.id, action: args[:action], reason: args[:reason],
                                instance_id: instance_id, automated: true)
    if !action_log.valid?
      puts action_log.errors.full_messages   
    else
      action_log.save!
    end
  end
end
