namespace :deployment do
  namespace :crontab do
    [:production, :staging].each do |deploy_type|
      desc "Show cron tab entries for #{deploy_type}"
      task deploy_type do
        puts crontab(deploy_type)
      end
    end
  end

  desc 'clean up dead resque workers'
  task :prune_resque_workers  => :environment do
    Resque.workers.first.prune_dead_workers if Resque.workers.any?
  end
end

def app_name(deploy_type)
  case deploy_type
  when :production
    'flight-control'
  when :staging
    'flight-control-staging'
  else
    raise "Don't know how to handle remote: '#{remote}'"
  end
end

def crontab(deploy_type)
  variables = { remote: deploy_type, name: app_name(deploy_type) }
  render_erb(crontab_template, variables)
end

def crontab_template
  File.read(File.join(Rails.root, '/lib/deployment/crontab.erb'))
end

def render_erb(template, variables)
  safe_level = 0
  trim_mode = '-'
  ERB.new(template, safe_level, trim_mode).result(
    OpenStruct.new(variables).instance_eval { binding }
  )
end
