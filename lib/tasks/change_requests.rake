namespace :change_requests do
  desc "Check & update if pending change request completed for one project"
  task :by_project, [:project, :slack, :text] => :environment do |task, args|
    project = Project.find_by(name: args[:project])
    if !project
      puts "No project found with that name"
    else
      ChangeRequestsJob.perform_later(project.id, args[:slack] == "true", args[:text] == "true")
    end
  end

  task :all,[:slack, :text] => :environment do |task, args|
    args = TaskArgsHelper.truthify_args(args)
    Project.active.each do |project|
      ChangeRequestsJob.perform_later(project.id, args[:slack], args[:text])
    end
  end
end
