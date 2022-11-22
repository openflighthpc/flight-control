namespace :sso do
  desc 'Sync changes to SSO accounts to Flight Control users'
  task sync: :environment do
    SsoSyncJob.perform_later
  end
end
