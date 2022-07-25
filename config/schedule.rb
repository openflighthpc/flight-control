# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
set :environment, ENV['RAILS_ENV'] || 'development'
job_type :rake, "cd :path && RAILS_ENV=:environment bundle exec rake :task :output"

every :day, at: '12:00pm' do
  rake "daily_reports:generate:all[latest,true]"
end

every :day, at: '12:00am' do
  rake "instance_details:record"
end

every :day, at: '12:00am' do
  rake "sso:sync"
end

every 5.minutes do
  rake "instance_logs:record:all[true]"
end

every 1.minute do
  rake "change_requests:all[true,false]"
end

every 20.minutes do
  rake "projects:monitor:all"
end

every :day, at: '12:30pm' do
  rake "projects:budget_switch_off_schedule:all[true,false]"
end

every :day, at: '11:30pm' do
  rake "projects:budget_switch_offs:all[true,false]"
end
