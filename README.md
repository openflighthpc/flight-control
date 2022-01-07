# README

## Initial Setup

- Ensure PostgreSQL is installed on your device
- Create a PostgreSQL user with database creation and editing rights, and a password
- Update `config/database.yaml`, replacing `username` with the name of the user you just created
- Set the environment variable `CCV_DATABASE_PASSWORD` with the user's password
- If running in production:
  - Set the `SECRET_KEY_BASE` environment variable
    - The value for this should be retrieved from `rake secret`
  - Set the `RAILS_ENV` environment variable to `production`
  - Run `bundle exec rake assets:precompile`
- Run `bundle install`
- Run `yarn`
- Run `rails db:create`
- Run `rails db:migrate`

## Operation

- Run the application with `rails s`
- By default it will be accessible at `http://localhost:3000/`

## Configuration

### AWS

On AWS, projects can be tracked on an account or project tag level. For tracking by project tag, ensure that all desired resources are given a tag with the key `project` and the same value as `project_tag` saved for the project. Account level will include any subaccounts.

##### Resource tagging

When creating an instance via the AWS online console, any specified tags will be propagated to its related resources. However, this does not occur when adding tags post-creation, and related resources will need to be tagged explicitly.

When creating instances via CloudFormation, related resources will need to be explicitly tagged regardless of when you add tags to the instance (see https://aws.amazon.com/premiumsupport/knowledge-center/cloudformation-instance-tag-root-volume/ for more details).

It is recommended to check that all expected resources (IPs, volumes, etc/) have the expected tag before configuring the project tracking. It is recommended that tags are added even if the intention is to track by account, to allow for greater flexibility and accuracy if a second project is later added to the same account.

Please note that if you change a project's `filter_level` and/or `project_tag` and generate new cost logs for a prior date, this will overwrite the data using the current filter level/ project tag.

##### Instance type tags

This application includes in its breakdown details of instances specifically used as compute nodes. For this to be measured accurately, the appropriate instances should have a tag added with the key `type` and the value `compute`. Again, these should be added at the point of creation. If compute groups are also being used, these should be added using the tag `compute_group`, with a value of the group name. Similarly, core infrastructure can be identified using a tag with the key `type` and the value `core`.

##### Admin

The project and compute tags must be activated in the Billing console (see https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/activating-tags.html). It may take up to 24 hours for new tags to appear in this console.

This application makes use of a number of AWS sdks, which require a valid `Access Key ID` and `Secret Access Key`. This should relate to a user with access to: Billing and Cost Management, Cost Explorer API, EC2 API and Pricing API.

### Azure

In this application, Azure projects are tracked either by a subscription, or by one or more resource groups (that must be part of the same subscription). In addition, it is required that compute nodes be given the `"type" => "compute"` tag on the Azure platform and core infrastructure given the `"type" => "core"` tag. If compute groups are being used, compute nodes must also be identified with the tag `"compute_group" => "groupname"`.

Tags are available in the Azure instances API after a few minutes, but will only be reflected in costs for dates/times after the tags have been added.

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

### Adding and updating projects

A `Project` must be created for each project you wish to track. These can be created by running `rake projects:manage` and following the prompts in the command line. This file can also be used to update existing projects. Projects should not be deleted, but instead `archived` set to `true` to mark them as inactive.

### Recording instance logs

To record the latest instance logs, these can be generated using `rake instance_logs:record:all[rerun]` or `rake instance_logs:record:by_project[project_name,rerun]`. If `rerun` is set to `true`, any existing instance logs will be updated. For example `rake instance_logs:record:by_project[project1,true]` would record instance logs for the project named project1, replacing any existing logs already recorded for today.

Instance logs will only be recorded/updated if the project is active.
