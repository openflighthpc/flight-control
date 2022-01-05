# README

## Initial Setup

- Ensure PostgreSQL is installed on your device
- Create a PostgreSQL user with database creation and editing rights, and a password
- Update `config/database.yaml`, replacing `username` with the name of the user you just created
- Set the environment variable `CCV_DATABASE_PASSWORD` with the user's password
- Run `bundle install`
- Run `yarn`
- Run `rails db:create`
- Run `rails db:migrate`
- If running in production:
  - Set the `SECRET_KEY_BASE` environment variable
    - The value for this should be retrieved from `rake secret`
  - Set the `RAILS_ENV` environment variable to `production`
  - Run `bundle exec rake assets:precompile`

## Operation

- Run the application with `rails s`
- By default it will be accessible at `http://localhost:3000/`
