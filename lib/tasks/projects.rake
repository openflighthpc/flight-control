require_relative "../../app/models/application_record"
require_relative "../project_manager"

namespace :projects do
  desc "Create or update a project"
  task :manage => :environment do |task, args|
    ProjectManager.new.add_or_update_project
  end

  namespace :create_config do
    desc "Create config for all active projects"
    task :all, [:overwrite] => :environment do |task, args|
      overwrite = args["overwrite"] == "true"
      Project.active.each do |project|
        begin
          project.create_config(overwrite)
        rescue => error
          puts "Unable to create config for #{project.name}: #{error}"
        end
        puts
      end
    end

    desc "Create config for one project"
    task :by_project, [:project, :overwrite] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
      else
        overwrite = args["overwrite"] == "true"
        begin
          project.create_config(overwrite)
        rescue => error
          puts "Unable to create config for #{project.name}: #{error}"
        end
      end
    end
  end

  namespace :monitor do
    desc "Run CPU utilisation monitoring script for a single project"
    task :by_project, [:project] => :environment do |task, args|
      project = Project.find_by(name: args["project"])
      if !project
        puts "No project found with that name"
        return
      elsif !project.monitor_currently_active?
        puts "Monitor not currently active for this project"
      else
        MonitorJob.perform_later(project.id)
      end
    end

    desc "Run CPU utilisation monitoring script for all projects"
    task :all => :environment do |task|
      Project.active.each do |p|
        begin
          next if !p.monitor_currently_active?
        rescue Errno::ENOENT => e
          puts "Error monitoring #{p.name}: #{e.message}"
          next
        end
        MonitorJob.perform_later(p.id)
      end
    end
  end

  namespace :budget_switch_off_schedule do
    desc "Show over budget switch off schedules for all active projects"
    task :all, [:slack, :text] => :environment do |task, args|
      args = TaskArgsHelper.truthify_args(args)
      Project.active.pluck(:id).each do |project_id|
        SwitchOffScheduleJob.perform_later(project_id, args[:slack], args[:text])
      end
    end

    desc "Show over budget switch off schedule for a given project"
    task :by_project, [:project, :slack, :text] => :environment do |task, args|
      project = Project.find_by(name: args[:project])
      if !project
        puts "No project found with that name"
      else
        SwitchOffScheduleJob.perform_later(project.id, args[:slack] == "true", args[:text] == "true")
      end
    end
  end
  
  namespace :budget_switch_offs do
    desc "Carry out any over budget scheduled switch offs for all active projects"
    task :all, [:slack, :text]  => :environment do |task, args|
      args = TaskArgsHelper.truthify_args(args)
      Project.active.pluck(:id).each do |project_id|
        BudgetSwitchOffsJob.perform_later(project_id, args[:slack], args[:text])
      end
    end

    desc "Carry out any over budget switch offs for a given project"
    task :by_project, [:project, :slack, :text] do |task, args|
      project = Project.find_by(name: args[:project])
      if !project
        puts "No project found with that name"
      else
        BudgetSwitchOffsJob.perform_later(project.id, args[:slack] == "true", args[:text] == "true")
      end
    end
  end
end
