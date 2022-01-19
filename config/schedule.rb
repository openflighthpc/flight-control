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
job_type :rake, "cd :path && bundle exec rake :task :output"

every :day, at: '12:00pm' do
  rake "daily_reports:generate:all[latest,true]"
end

every :day, at: '12:00am' do
  rake "instance_details:record"
end

every 5.minutes do
  rake "instance_logs:record:all[true]"
end
