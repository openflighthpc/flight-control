# Flight Control

A tool for tracking costs and managing instances on AWS and Azure.

## Overview

A Ruby on Rails application for recording and viewing costs for projects hosted on AWS and Azure, and for recording, viewing and managing instance statuses.

## Initial Setup

- Esure Ruby (2.5.1) and Bundler are installed on your device
- Ensure PostgreSQL is installed on your device
- Create a PostgreSQL user with database creation and editing rights, and a password
- Update `config/database.yaml`, replacing `username` with the name of the user you just created
- Set the environment variable `CCV_DATABASE_PASSWORD` with the user's password
- If running in production:
  - Set the `RAILS_ENV` environment variable to `production`
- Run `bundle install`
- Run `rails db:create`
- Run `rails db:migrate:with_data`

## Configuration

### Global Config

In addition to setting the database username and password in `config/database.yaml`, the following config variables should be set for the development and production files in `config/environments`:

- `config.slack_token`: authorisation token for sending slack messages
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

The application includes the option to send results to slack, specifying a specific channel for each project. To use this function, a slack bot (https://slack.com/apps/A0F7YS25R-bots) must be created. The bot's API Token should then be used to set `config.slack_token` in `config/environments/development.rb` and `config/environments/production.rb`.

This bot must be invited to each project's chosen slack channel.

### Adding and updating projects

A `Project` must be created for each project you wish to track. These can be created by running `rake projects:manage` and following the prompts in the command line. This task can also be used to update existing projects. Projects should not be deleted, but instead `archived` set to `true` to mark them as inactive.

### Recording instance logs

To record the latest instance logs, run:

`rake instance_logs:record:all[rerun,verbose]` or 
`rake instance_logs:record:by_project[project_name,rerun,verbose]`

If `rerun` is set to `true`, any existing instance logs will be updated. For example `rake instance_logs:record:by_project[project1,true]` would record instance logs for the project named project1, updating any existing logs already recorded for today (if any changes).

`verbose` should be set to `true` to see full error messages, if running the task is failing.

Instance logs should be recorded as soon as a project is created (and instances are created on the platform) to ensure accuracy of other functions, such as recording cost logs and recording instance sizes and prices.

Logs will only be recorded/updated if the project is active.

### Recording cost logs

To record the latest instance logs, run:

`rake cost_logs:record:all[date,rerun,text,verbose]` or 
`rake cost_logs:record:by_project[project_name,date,rerun,text,verbose]` or
`rake cost_logs:record:range[project_name,start_date,end_date,rerun,text,verbose]`

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

`rake daily_reports:generate:all[date,slack,text,rerun,verbose]` or 
`rake daily_reports:generate:by_project[project,date,slack,text,rerun,verbose]`

`date` can be set in the format yyyy-mm-dd or with `latest`, which will use the most recent date with cost data available.

This will include generating cost logs if none are present, or updating them if `rerun` is set to `true`.

If `slack` is set to `true`, the daily report will be sent to the project's `slack_channel`.

### Instance Mappings

Instance mappings can be used to translate platform names (e.g. t2.micro or Standard_B1ls) into more customer friendly names, such as Compute (Medium).

Instance mappings can be managed using the rake tasks:
- `rake instance_mappings:list`
- `rake instance_mappings:create[platform,instance_type,customer_facing]`
- `rake instance_mappings:update[platform,instance_type,new_customer_facing]
- `rake instance_mappings:delete[platform,instance_type]`

A default set of instance mappings are created during project setup.

### Instance Prices and Sizes

Instance prices and sizes (GPUS, CPUs and RAM) are saved in text files in `lib/platform_files`. These should be updated regularly, by running `rake instance_details:record`.

This may take a few minutes to complete, especially for Azure data due to limitations in the Azure APIs.

As there are thousands of instance type and region combinations, these are only recorded for those matching existing instance logs (for all projects, for all dates). If a new instance is created with a new region and/or instance type, this task should be rerun.

This uses the credentials of the first active project for each platform. If there are no such projects an alert highting this will be shown on the command line and it will not run for that platform.

#### Region name mappings

Both AWS and Azure use non standard region names in their pricing/size APIs/SDKs. To ensure the correct region names are used for these queries, these are mapped against instance region names in `aws_region_names.txt` and `azure_region_names.txt`. When adding resources in a new region, the related file should be checked to ensure a mapping is present.

For AWS projects, a missing mapping will be highlighted when adding regions using `rake:projects:manage`. At the time of writing, AWS mappings can be found at https://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region but unfortunately Azure do not publicly provide such a list.


### Schedule tasks

Rake tasks such as generating daily reports, recording instance logs and recording instance details can be scheduled by defining their timings in `config/schedule.rb`. Once updated in this file, corresponding cron syntax can be determined by running `whenever` in the command line, or your crontab updated automatically with these lines by running `whenever --w`.
