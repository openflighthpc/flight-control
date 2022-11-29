# Flight Control

A tool for tracking costs and managing instances on AWS and Azure.

## Overview

A Ruby on Rails application for recording and viewing costs for projects hosted on AWS and Azure, and for recording, viewing and managing instance statuses.

## Initial Setup

- Esure Ruby (2.5.1) and Bundler are installed on your device
- Ensure PostgreSQL is installed on your device
- Create a PostgreSQL user with database creation and editing rights, and a password
- Update the application's database credentials using `EDITOR=vim rails credentials:edit` (replacing `vim` with the editor of your choice) and setting:
  - `database_username`
  - `database_password`
  - `slack_token`
  - `secret_key_base`, generated using `rake secret`
- Ensure you save a backup copy of the file `config/master.key` (used for encryption of these credentials)
- If running in production:
  - Set the `RAILS_ENV` environment variable to `production`
  - Set the `RAILS_SERVE_STATIC_FILES` environment variable to `true`
  - Run `bundle exec rake assets:precompile`
- Run `bundle install`
- Run `yarn`
- Run `rails db:create`
- Run `rails db:migrate:with_data`

## Operation

- Run the application with `rails s`
- By default it will be accessible at `http://localhost:3000/`. This can be changed by adding `-b` and `-p` when running `rails s`. For example `rails s -b 0.0.0.0 -p 4567`
- By default it will run as `development`, but can this can be changed by setting the environment variable `RAILS_ENV` to `production`

## Configuration

### Global Config

In addition to setting the database username and password in `config/database.yaml`, the following config variables should be set for the development and production files in `config/environments`:

- `config.usd_gbp_conversion`: USD to GBP exchange rate
- `config.gbp_compute_conversion`: conversion rate for GBP to compute units
- `config.at_risk_conversion`: conversion rate for compute units to 'at risk' compute units

### AWS

On AWS, projects can be tracked on an account or project tag level. For tracking by project tag, ensure that all desired resources are given a tag with the key `project` and the same value as `project_tag` saved for the project. A project tracked at account level will include any subaccounts.

##### Type and compute group tags

For `compute` costs to be measured accurately, the appropriate instances and disks should have a tag added with the key `type` and the value `compute`. Again, these should be added at the point of creation. Compute groups must also be added using the tag `compute_group`, with a value of the group name.

Similarly, core infrastructure must be identified using a tag with the key `type` and the value `core`.

##### Resource tagging

When creating an instance via the AWS online console, any specified tags will be propagated to its related resources. However, this does not occur when adding tags post-creation, and related resources will need to be tagged explicitly.

When creating instances via CloudFormation, related resources will need to be explicitly tagged regardless of when you add tags to the instance (see https://aws.amazon.com/premiumsupport/knowledge-center/cloudformation-instance-tag-root-volume/ for more details).

It is recommended to check that all expected resources (IPs, volumes, etc/) have the expected tag before configuring the project tracking. It is recommended that tags are added even if the intention is to track by account, to allow for greater flexibility and accuracy if a second project is later added to the same account.

Please note that if you change a project's `filter_level` and/or `project_tag` and generate new cost logs for a prior date, this will overwrite the data using the current filter level/ project tag.

##### Admin

The project and compute tags must be activated in the Billing console (see https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/activating-tags.html). It may take up to 24 hours for new tags to appear in this console.

This application makes use of a number of AWS sdks, which require a valid `Access Key ID` and `Secret Access Key`. This should relate to a user with access to: Billing and Cost Management, Cost Explorer API, EC2 API and Pricing API.

### Azure

In this application, Azure projects are tracked either by a subscription, or by one or more resource groups (that must be part of the same subscription).

In order to run the application, an app and service principal must be created in Azure Active Directory (see https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal for more details).

`Account Owner can view charges` must be set for the subscription and the following permissions set for the app:

- `Reader` level access to the subscription
- `User.Read` for the Microsoft.Graph service
- `Microsoft.Compute/*/read` for the Virtual Machines service

And if using the `visualiser` part of this application (future):
- `Microsoft.Compute/virtualMachines/start/action`
- `Microsoft.Compute/virtualMachines/restart/action`
- `Microsoft.Compute/virtualMachines/deallocate/action`

Azure projects require the following details to be obtained prior to project creation:

- Directory (tenant) ID
- Client (application) ID
- Client secret
- Subscription ID
- Resource group name(s), if the project is set at resource group level

The first three can be obtained via the app you created in Azure Active Directory. The subscription ID is located in the overview for the subscription containing the project, as is the resource group name in the overview for the resource group. A project may have more than one resource group, but these must be part of the same subscription.

##### Type and compute group tags

Compute nodes and their disks must be given the `"type" => "compute"` tags and `"compute_group" => "groupname"` on the Azure platform. Core infrastructure (including disks) must be given the `"type" => "core"` tag.

Tags are available in the Azure instances API after a few minutes, but will only be reflected in costs for dates/times after the tags have been added.

### Slack

The application includes the option to send results to slack, specifying a specific channel for each project. To use this function, a slack bot (https://slack.com/apps/A0F7YS25R-bots) must be created. The bot's API Token should then be used to set the value of `slack_token` in the application's credentials (using `EDITOR=vim rails credentials:edit`).

This bot must be invited to each project's chosen slack channel.

### Adding and updating projects

A `Project` must be created for each project you wish to track. These can be created by running `rake projects:manage` and following the prompts in the command line. This task can also be used to update existing projects. Projects should not be deleted, but instead set the `archived_date` to mark them as inactive.

Project names must start with a letter, only include lower or uppercase letters, numbers, dashes or underscores, and must end in a letter or number.

#### Balances and budgets

As part of creating and updating a project, a balance and budget policy must be set. Balances represent the total amount of compute units assigned to the project and budget policies describe how those compute units will be allocated over time.

Budget policies include a number of attributes:
- Cycle interval: length of a billing cycle. Can be monthly, weekly or custom
- Days: Describes how many days a custom cycle interval lasts
- Spend profile: how cycle budgets are calculated
  - Fixed: budget resets start of each cycle to the value of cycle limit (see below)
  - Rolling: (budget cycles so far * cycle limit) - total spend so far
  - Continuous: balance - total spend so far
  - Dynamic: (balance - total spend so far) / remaining cycles
- Cycle limit: compute units assigned to the cycle, for fixed and rolling spend profiles.

Both balances and budget policies have an `effective_at` date. When a project reaches its end date, the balance will become zero.

### Instance Mappings

Instance mappings can be used to translate platform names (e.g. t2.micro or Standard_B1ls) into more customer friendly names, such as Compute (Medium).

Instance mappings can be managed using the rake tasks:

- `rake instance_mappings:list`
- `rake instance_mappings:create[platform,instance_type,customer_facing]`
- `rake instance_mappings:update[platform,instance_type,new_customer_facing]`
- `rake instance_mappings:delete[platform,instance_type]`

A default set of instance mappings are created during project setup.

#### Generate project config

If using the visualiser part of the application, once instance logs have been created for a project (see below), config
must be generated using `rake projects:create_config:by_project[project,update]` or `rake projects:create_config:all[update]`.

If update is set to true, new compute groups and instance types will be added, instance limits updated, and any old
groups or types removed.

Compute group colours and priorities and instance type priorities should be updated once this has been generated.
On the `/policies` page, these attributes can be updated, and config updated (as if running the above rake task).

### Recording instance logs

To record the latest instance logs, run one of:

- `rake instance_logs:record:all[rerun,verbose]`
- `rake instance_logs:record:by_project[project_name,rerun,verbose]`

If `rerun` is set to `true`, any existing instance logs will be updated. For example `rake instance_logs:record:by_project[project1,true]` would record instance logs for the project named project1, updating any existing logs already recorded for today (if any changes).

`verbose` should be set to `true` to see full error messages, if running the task is failing.

Instance logs should be recorded as soon as a project is created (and instances are created on the platform) to ensure accuracy of other functions, such as recording cost logs and recording instance sizes and prices.

Logs will only be recorded/updated if the project is active.

### Recording cost logs

To record the latest cost logs, run one of:

- `rake cost_logs:record:all[date,rerun,text,verbose]`
- `rake cost_logs:record:by_project[project_name,date,rerun,text,verbose]`
- `rake cost_logs:record:range[project_name,start_date,end_date,rerun,text,verbose]`

`date` can be specified in the format yyyy-mm-dd, or if `latest` is entered, the date for 3 days ago will be used, as this is the most recent date when cost data is (reliably) made available by Azure and AWS.

When running `range` you can specify a start and and end date (inclusive). For Azure projects, due to limitations of the Azure APIs, generating logs for a range may take some time (5+ mins per month of data).

If `rerun` is set to `true`, any existing cost logs will be updated (if any changes). If `text` is set to `true`, the result of the task will be printed to the command line.

`verbose` should be set to `true` to see full error messages, if running the task is failing.

#### Cost log scopes

Cost logs will be recorded for each project with the following scopes:
- Total
- Data Out
- Core costs (excluding storage and data out costs)
- Core storage
- Instance costs for each compute group
- Storage costs for each compute group

Compute groups are determined based on the project's latest instance logs.

### Daily Reports

A high level summary of a project's costs can be generated using the tasks:

- `rake daily_reports:generate:all[date,slack,text,rerun,verbose]`
- `rake daily_reports:generate:by_project[project,date,slack,text,rerun,verbose]`

`date` can be set in the format yyyy-mm-dd or with `latest`, which will use the most recent date with cost data available.

This will include generating cost logs if none are present, or updating them if `rerun` is set to `true`.

If `slack` is set to `true`, the daily report will be sent to the project's `slack_channel`.


### Instance Prices and Sizes

Instance prices and sizes (GPUS, CPUs and RAM) are recorded automatically each day. These details can also be updated manually by running `rake instance_details:record`.

This may take a few minutes to complete, especially for Azure data due to limitations in the Azure APIs.

As there are thousands of instance type and region combinations, these are only recorded for those matching existing instance logs (for all projects, for all dates). If a new instance is created with a new region and/or instance type, this task should be rerun.

This uses the credentials of the first active project for each platform. If there are no such projects an alert highting this will be shown on the command line and it will not run for that platform.

If a query to the AWS/Azure API fails for any reason, no changes will be made to the recorded details. However, if the data obtained from a query contains missing or invalid values, these will be replaced with default values (`nil` for numeric values and 'UNKNOWN' for string values). A warning will also be displayed on the 'Costs breakdown' and 'Create/Manage events' web pages.

#### Region name mappings

Both AWS and Azure use non standard region names in their pricing/size APIs/SDKs. To ensure the correct region names are used for these queries, these are mapped against instance region names in `aws_region_names.txt` and `azure_region_names.txt`. When adding resources in a new region, the related file should be checked to ensure a mapping is present.

For AWS projects, a missing mapping will be highlighted when adding regions using `rake:projects:manage`. At the time of writing, AWS mappings can be found at https://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region but unfortunately Azure do not publicly provide such a list.


### Schedule tasks

Rake tasks such as generating daily reports, recording instance logs and recording instance details can be scheduled by defining their timings in `config/schedule.rb`. Once updated in this file, corresponding cron syntax can be determined by running `whenever` in the command line, or your crontab updated automatically with these lines by running `whenever --w`.

In production, if deployed using dokku, whenever should not be used. Instead, necessary cron entries can be determined
using the rake task `rake deployment:crontab:staging` or `rake deployment:crontab:production`
These should be added to the host's crontab, not the application container's.

### Background jobs

The majority of scheduled tasks are carried out as background jobs. In development these are by default
performed `inline`, meaning they are sequential. In production, if a `REDIS_URL` environment
variable is set, resque is used instead to process these jobs, with jobs assigned to queues
and carried out by resque workers in parallel. Jobs are placed in the queues high, medium and low,
reflecting the priority the resque workers will complete them in.

The application's `Procfile` creates a container specifically for resque in dokku and creates
5 resque workers. This will require monitoring and possibly increasing as the number of active
projects grows.

The use of `inline` or `resque` can be overridden by defining an environment variable of `QUEUE_ADAPTER`.
This may be useful if you want to run rake tasks with text output in production, as with resque
the output will be made a resque worker (and so not visible in the console the rake task is made from).
E.g. `ENV['QUEUE_ADAPTER']=inline rake daily_reports:all[latest,true,true,true]`

Admins can view the status of resque by visiting the path `/resque`

**Note**: the version of the dokku-redis plugin on our hosting instances is outdated, and so to prevent
issues `config/initilizers/resque.rb` includes logic to ensure Control can successfully communicate
with the (old) version of redis. If we update dokku-redis and then the version of redis this will likely no longer be required.

## Visualiser

### Users

Projects and the events belonging to them can only be accessed by users with the given permissions to do so.

#### User management

Rake tasks exists for the creation and archival of users, as well as the mutation of their permissions.

The most important user tasks are as follows:

- `rake users:create[username,password]` - Create a user with the given username. Password is an optional argument; if not given, a random base 58 string will be generated and output to the console.
- `rake users:create_admin[username,password]` - Create an admin user. Admin users have permission for _all actions_ across _all projects_.
- `rake users:archive[username]` - Archive a user. An archived user will not be able to log in.
- `rake users:activate[username]` - Activate a previously archived user.

#### User roles

All of a user's permissions across projects are handled by user roles. User roles are hard-coded in `app/models/user_role.rb`.

The most important user role tasks are as follows:

- `rake users:roles:assign[username,project,role]` - Create role `role` for user `username` on project `project`. For example, `rake users:roles:assign[myuser,democluster,viewer]`. Will give `myuser` the `viewer` role for project `democluster`. They will have read-only permissions for the project with no executive permissions.
- `rake users:roles:revoke[username,project,role]` - Revoke a role for a given user and cluster. Similar to `assign`, but it removes the given role.

#### Flight SSO integration

This application has the capacity to authenticate users via a Flight SSO server. To do so, some configuration is required:

- The `JWT_SECRET` environment variable must be set. This is a shared secret used to decode JSON Web Tokens given out by Flight SSO.
- The `sso_cookie_name` and `sso_uri` keys must be set in `config/environments/*.rb`.
  - `sso_cookie_name` is the name of the cookie that the SSO session will be stored in. This must match the cookie name being used by SSO.
  - `sso_uri` is the URI used to reach the SSO server. It should be the host and port, _not_ including the path.
  - `sso_domain` is the domain that the cookie will be created under. Again, it should match the SSO server in use.

A rake task (`rake sso:sync`) and cron schedule item have been created for syncing the user database to the SSO database. The `JWT_SECRET` environment variable is required for it to work. The sync task will query the SSO database for users, create an SSO user in Control for any that don't already exist, and update any username/email discrepancies locally.

SSO user objects should be treated like any 'local' user, in that it can be archived/activated and have user roles created/revoked for it.

### Costs Breakdown

#### Selected Project

By default this page shows data for the first active project. This can be changed by adding the url parameter `project=projectname`. This logic will change once users and login has been implemented.

#### Costs Charts

This page shows historic and estimated future costs in at risk compute units, based on cost logs, instance logs and change requests. These can be viewed in either a daily breakdown or cumulative chart, which can be moved between by selecting the relevant tab.

Compute forecasts for today and future days are based upon the current instance counts, action logs and change requests. For forecast days in the past (i.e. days between the last actual costs recorded and today) compute costs are estimated based on the instance counts and action logs on those days.

Non compute costs are based on the most recent recorded costs for that scope. For example, if core costs were last recorded as 10 compute units, all forecast days will estimate core costs to also be 10 compute units.

By default these charts will show the current billing cycle, but the date range can be altered using the form at the top of the page. The last day of a cycle or the project as a whole are shown on the charts. Costs continue to be shown until the project's `archived_date`.

Datasets's visibility can be toggled on the charts by selected them in the chart's legend. They can also be filtered using the form at the top of the page. If a compute group or core is selected, the corresponding storage dataset will also be shown (e.g. selecting 'group1' will show both 'group1' and 'group1 storage').

#### Budget Matching Switch Offs

The system will aim to match a project's budget, estimating when best to switch off nodes to make the most of the remaining budget for this cycle.

Switch offs are determined based on a weighted priority, calculated by multiplying a given instance type's priority by its compute group's priority, as defined in the project's config. Instance types with a lower weighted priority are switched off first. However, if switch offs of more expensive, higher priority instances leave enough remaining budget, lower priority instances may then be switched off later (or not at all) to make the most of this surplus.

Calculations are made based on the assumption that the suggested switch offs are made at 11:30pm on the given date.

Any recommended switch offs will be displayed on the costs charts. These switch offs will also be highlighted to the user upon submitting a change request and details included in the resulting slack message. Switch offs to meet budget may change over time as actual costs and new instance logs update forecasts.

These calculations may include switching off instances multiple times throughout the cycle, if they are turned back on by a subsequent change request.

If you select a date range including future cycles, switch offs for those future cycles will also be calculated.

##### Rake and cron tasks

Budget matching switch offs for today can be carried out using the rake task `rake projects:budget_switch_offs:all[slack,text]` or `rake projects:budget_switch_offs:by_project[project_name,slack,text]`. The arguments `slack` and `text` must be `true` or `false`, indicating how to output the results.

A cron task is also included in `config/schedule` that can be set using `whenever -w`. This will set the `:all` rake task to run at 11:30pm every day.

When such a switch off is carried out, associated ActionLogs are created.

A description of any upcoming budget switch offs can also be generated using the rake task `rake projects:budget_switch_off_schedule:all[slack,text]` or `rake projects:budget_switch_off_schedule:by_project[project_name,slack,text]`.

A cron task is included in `config/schedule` to run the `:all` task at 12:30pm every day, outputting the result to slack.

#### Current States

At the bottom of the page the project's current compute groups and instance counts are displayed, with a summary of the resulting estimated daily costs. If any filtering for compute groups is in place, only those compute groups will be included.

These groups and types shown in this table are determined by the project's config records (`ComputeGroupConfig` and `InstanceTypeConfig`). If this is not up to date this may not show the full/ correct details.

#### New Data Alert and Refresh

If new costs are recorded, instance counts change, a change request is created/updated or an automated budget matching switch off carried out, this page will show an alert that when accepted refreshes the page, so this latest data can be shown. The application checks for new data every 30 seconds.

### Change Requests

On the Create Event page, users can request to turn instances on or off by submitting a change request.

Change requests can either specify exact counts, which will turn instances on or off to meet the counts, or minimum counts, which will only turn instance on to meet the specified counts. If counts are already met, no actions will be taken.

These requests can either be carried out 'now', 5 minutes after submission(rounded up), or at a specified date and time in the future.

If in the future, the user can also optionally choose to repeat the request on the chosen days of the week, until the chosen end date (inclusive of that date). Users may also specify a description for these requests, and if it should include an override to the CPU monitor for a specified number of hours.

Once all request details have been selected, a chart will be displayed with the estimated resulting costs, for the current billing cycle. This will include displaying any required automated switch offs to best meet budget.

If this forecast will take the project over budget or over balance, the user will be preventing from submitting the request.

Upon submission a slack message will be sent to the project's defined slack channel.

#### Managing Requests

A project's active requests can be viewed on the Manage Events page. This shows the current node counts (excluding pending counts), any switch ons and switch offs in progress, any change requests starting in the next 5 minutes, and any change requests starting after the next 5 minutes.

Tables also include any calculated budget matching switch offs, which are highlighted in red.

This page updates automatically without needing to refresh, with data checked and updated every 30 seconds.

These tables include links for editing or cancelling requests. Requests can be cancelled if they have not yet been actioned, and can be edited if taking place more than 5 minutes in the future (or for repeated requests, if their next action is more than 5 minutes in the future).

When a request is canceled or updated, a slack message is sent and an accompanying `ChangeRequestAuditLog` is created recording the changes.

#### Carrying out requests

A cron job is specified as part of the configuration for whenever, that runs a rake task that checks for all due change requests each minute.

When the specified date(s) and time for a request is reached, its targets are compared to the current instance counts to determine what actions (if any) are required. If any, requests are submitted to the relevant cloud platform to switch on/off instances to meet the counts and an Action Log created for each action.

If the request includes a change to the monitor override this will also be updated and an associated ConfigLog created recording the details.

Pending instance counts (based on pending action logs) will be displayed in the instance counts charts on the costs breakdown and create event page.

When new instance logs are created, these are compared against any pending action logs. If the action logs' target states are reached, they are updated from a status of 'pending' to 'complete'.

#### Manual changes and action logs

If a user turns on or off an instance from outside this application, an action log must be created in order for it to have an accurate picture of the project and make appropriate forecasts.

An action log can be created using the task `rake action_logs:add [project_name,action,reason,instance_id,actioned_at_time]`.

`instance_id` here refers to the id given by the instance's platform and must be in the appropriate format. For example, for aws this would be something like `i-0b00efe3aab7010da`, or for azure `/subscriptions/#{subscription_id}/resourceGroups/#{resource_group}/providers/Microsoft.Compute/virtualMachines/#{instance_name}`.

`action` must be `on` or `off` and `actioned_at_time` in the format "yyyy-mm-dd HH:MM".

### CPU Monitor and idle node switch offs

Included in `config/schedule` is a cron task running every 20 minutes, that checks the CPU utilisation of any running nodes and switches them off if this is below the project's set `utilisation_threshold`. CPU utilisation is calculated as an average of the maximum values recorded over the past 20 minutes. If 20 minutes of data is not available, the utilisation will be treated as 100%.

These checks and switch offs can be disabled entirely by setting a project's `monitor_active` to `false` or `nil`. It can also be disabled temporarily by setting a value for the project's `override_monitor_until`, which must be a valid date & time.

If nodes are switched off as part of this process a slack message is sent to the project's slack channel with details, and associated action logs created.

### Project Policies

Settings for a project's `utilisation_threshold`, `override_monitor_until` and `monitor_active` attributes can be set on the project's policies page. Only admins and users with a default role for the project can access and use this page.

### Audit Logs

On the `audit` page, users can view a history of actions taken for a given project. This includes the creation of change requests, editing or cancelling of a change request, action logs and config logs.

These records can be filtered by any combination of compute group, user, log type, log status and by date.

# Deploying changes to staging

The staging server is currently a [dokku](https://dokku.com/) instance running
on secondary.apps.alces-flight.com and is available at
https://testing.staging.alces-flight.com/

To deploy a release to the staging server:

1. Ensure you have SSH access to secondary.apps.alces-flight.com
2. Add a git remote for secondary.apps.alces-flight.com: `git remote add
   dokku-staging dokku@secondary.apps.alces-flight.com:flight-control-staging`
3. Checkout the branch you want to deploy `git checkout <BRANCH YOU WANT TO
   DEPLOY>`
4. Push to the staging remote: `git push -f dokku-staging HEAD:master`
5. 5 minutes after deployment, SSH into secondary.apps, run `dokku enter flight-control-staging resque`, then `rake deployment:prune_resque_workers`
