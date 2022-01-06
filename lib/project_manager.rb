require_relative '../app/models/aws_project'
require_relative '../app/models/azure_project'
require 'table_print'

class ProjectManager
  def add_or_update_project(action=nil)
    if action == nil
      # will need to add validate back in once functionality added
      print "List, add or update project(s) (list/add/update)? "
      action = STDIN.gets.chomp.downcase.strip
    end
    if action == "update" || action == "validate"
      print "Project name: "
      project_name = STDIN.gets.chomp.strip
      project = Project.find_by_name(project_name)
      if project == nil
        puts "Project not found. Please try again."
        return add_or_update_project(action)
      end
    # if action == "validate"
    #   validate_credentials(project)
    #   return add_or_update_project
    # end
      show_attributes(project)
      update_attributes(project)
    elsif action == "add"
      add_project
    elsif action == "list"
      formatter = NoMethodMissingFormatter.new
      tp.set :max_width, 100
      tp Project.all, :id, :name, :platform, :start_date, :end_date, :archived,
      :visualiser, :slack_channel, {regions: {:display_method => :describe_regions, formatters: [formatter]}},
      {resource_groups: {:display_method => :describe_resource_groups, formatters: [formatter]}}, {filter_level: {formatters: [formatter]}},
      {project_tag: {formatters: [formatter]}}
      puts
      add_or_update_project
    else
      puts "Invalid selection, please try again."
      add_or_update_project
    end
  end

  def update_attributes(project)
    valid = false
    attribute = nil
    while !valid
      puts "What would you like to update? "
      attribute = STDIN.gets.chomp.strip
      if project.respond_to?(attribute.downcase) #|| attribute == "budget"
        valid = true
      else
        puts "That is not a valid attribute for this project. Please try again."
      end
    end

    if attribute == "regions"
      update_regions(project)
    elsif attribute == "resource_groups" || attribute == "resource groups"
      update_resource_groups(project)
    # elsif attribute == "budget"
    #   add_budget(project)
    else
      options = nil
      if attribute == "filter_level"
        options = project.platform == "aws" ? "tag/account" : "resource group/subscription"
      end
      value = get_non_blank(attribute, attribute, options)
      project.write_attribute(attribute.to_sym, value)
      if project.platform == "azure" && attribute == "filter_level" && project.filter_level == "resource group" && 
         !project.resource_groups.any?
        puts "This project has no resource groups - please add at least one."
        update_resource_groups(project)
      end
      if project.platform == "aws" && attribute == "filter_level" && project.filter_level == "tag" && !project.project_tag
        value = get_non_blank("Project tag", "Project tag")
        project.write_attribute(:project_tag, value)
      end
      valid = project.valid?
      while !valid
        project.errors.messages.each do |k, v|
          puts "#{k} #{v.join("; ")}"
          puts "Please enter new #{k}"
          value = get_non_blank(k)
          project.write_attribute(k, value)
        end
        valid = project.valid?
      end
      project.save!
      puts "#{attribute} updated successfully"
    end
    # stop = false
    # while !stop
    #   valid = false
    #   while !valid
    #     print "Would you like to validate the project's credentials (y/n)? "
    #     response = STDIN.gets.chomp.downcase.strip
    #     if response == "n"
    #       stop = true
    #       valid = true
    #     elsif response == "y"
    #       valid = true
    #     else
    #       puts "Invalid response. Please try again"
    #     end
    #   end
    #   if !stop
    #     validate_credentials(project)
    #     stop = true
    #   end
    # end
    puts "Would you like to update another field (y/n)?"
    action = STDIN.gets.chomp.downcase.strip
    if action == "y"
      return update_attributes(project)
    end
  end

  def update_regions(project)
    aws_regions = []
    file = File.open('./lib/platform_files/aws_region_names.txt')
    file.readlines.each do |line|
      line = line.split(",")
      aws_regions << line[0]
    end
    stop = false
    valid = false
    while !stop
      puts "Regions: #{project.regions.join(", ")}"
      while !valid
        puts "Add or delete region (add/delete)? "
        response = STDIN.gets.chomp.downcase.strip
        if response == "add"
          valid = true
          region = get_non_blank("Add region (e.g. eu-central-1)", "Region")
          continue = false
          while !continue
            if !aws_regions.include?(region)
              puts "Warning: #{region} not found in list of valid aws regions. Do you wish to continue (y/n)? "
              response = STDIN.gets.chomp.downcase.strip
              if response == "n"
                return update_regions(project)
              elsif response != "y"
                puts "Invalid select, please try again"
              else
                continue = true
              end
            else
              continue = true
            end
          end
          project.regions << region
          project.save!
          puts "Region added"
        elsif response == "delete"
          if project.regions.length > 1
            valid = true
            present = false
            while !present
              # we want to allow blanks here so can delete if one (somehow) previously added
              print "Region to delete: "
              to_delete = STDIN.gets.chomp.strip
              present = project.regions.include?(to_delete)
              if present
                project.regions.delete(to_delete)
                project.save!
                puts "Region deleted"
              else
                puts "Region #{to_delete} not present for this project"
              end
            end
          else
            puts "Cannot delete as must have at least one region"
          end
        else
          puts "Invalid response, please try again"
        end
      end
      yes_or_no = false
      while !yes_or_no
        print "Add/ delete another region (y/n)? "
        action = STDIN.gets.chomp.downcase.strip
        if action == "n"
          stop = true
          yes_or_no = true
        elsif action != "y"
          puts "Invalid option. Please try again"
        else
          stop = false
          yes_or_no = true
          valid = false
        end
      end
    end
  end

  def update_resource_groups(project)
    stop = false
    valid = false
    while !stop
      puts "Resource groups: #{project.resource_groups.join(", ")}"
      while !valid
        puts "Add or delete resource group (add/delete)? "
        response = STDIN.gets.chomp.downcase.strip
        if response == "add"
          valid = true
          project.resource_groups << get_non_blank("Add resource group", "Resource group").downcase
          project.save!
          puts "Resource group added"
        elsif response == "delete"
          if project.resource_groups.length > 1
            valid = true
            present = false
            while !present
              # we want to allow blanks here so can delete if one (somehow) previously added
              print "Resource group to delete: "
              to_delete = STDIN.gets.chomp.downcase.strip
              present = project.resource_groups.include?(to_delete)
              if present
                project.resource_groups.delete(to_delete)
                project.save!
                puts "Resource group deleted"
              else
                puts "Resource group #{to_delete} not present for this project"
              end
            end
          else
            puts "Cannot delete as must have at least one resource group"
          end
        else
          puts "Invalid response, please try again"
        end
      end
      yes_or_no = false
      while !yes_or_no
        print "Add/ delete another resource group (y/n)? "
        action = STDIN.gets.chomp.downcase.strip
        if action == "n"
          stop = true
          yes_or_no = true
        elsif action != "y"
          puts "Invalid option. Please try again"
        else
          stop = false
          yes_or_no = true
          valid = false
        end
      end
    end
  end

  def add_project
    attributes = {}
    print "Project name: "
    attributes[:name] = STDIN.gets.chomp.strip
    valid = false
    while !valid
      print "Platform (aws or azure): "
      value = STDIN.gets.chomp.downcase.strip
      valid = ["aws", "azure"].include?(value)
      valid ? attributes[:platform] = value : (puts "Invalid selection. Please enter aws or azure.")
    end
    attributes[:type] = "#{attributes[:platform].capitalize}Project"
    valid_date = false
    while !valid_date
      print "Start date (YYYY-MM-DD): "
      valid_date = begin
        Date.parse(STDIN.gets.chomp.strip)
      rescue ArgumentError
        false
      end
      if valid_date
        attributes[:start_date] = valid_date
      else
        puts "Invalid date. Please ensure it is in the format YYYY-MM-DD"
      end
    end
    valid_date = false
    while !valid_date
      print "End date (YYYY-MM-DD). Press enter to leave blank: "
      date = STDIN.gets.chomp.strip
      break if date.empty?
      valid_date = begin
        Date.parse(date)
      rescue ArgumentError
        false
      end
      if valid_date
        attributes[:start_date] = valid_date
      else
        puts "Invalid date. Please ensure it is in the format YYYY-MM-DD"
      end
    end
  
  # budget = nil
  # valid = false
  # while !valid
  #   budget = get_non_blank("Budget amount (c.u./month)", "Budget")
  #   valid = begin
  #     Integer(budget, 10)
  #   rescue ArgumentError, TypeError
  #     false
  #   end
  #   puts "Please enter a number" if !valid
  # end
    attributes[:slack_channel] = get_non_blank("Slack Channel", "Slack Channel")

    if attributes[:platform].downcase == "aws"
      attributes[:regions] = []
      attributes[:regions] << get_non_blank("Add region (e.g. eu-west-2)", "Region").downcase
      stop = false
      while !stop
        valid = false
        while !valid
          print "Additional regions (y/n)? "
          response = STDIN.gets.chomp.downcase.strip
          if response == "n"
            stop = true
            valid = true
          elsif response == "y"
            valid = true
          else
            puts "Invalid response. Please try again"
          end
        end
        if !stop
          attributes[:regions] << get_non_blank("Additional region (e.g. eu-central-1)", "Region")
        end
      end
      attributes[:security_id] = get_non_blank("Access Key Id")
      attributes[:security_key] = get_non_blank("Secret Access Key")
      valid = false
      while !valid
        print "Filtering level (tag/account): "
        response = STDIN.gets.strip.downcase
        if ["tag", "account"].include?(response)
          valid = true
          attributes[:filter_level] = response
        else
          puts "Invalid selection. Please enter tag or account"
         end
      end
      if attributes[:filter_level] == "tag"
        attributes[:project_tag] = get_non_blank("Project tag", "Project tag")
      end
    else
      attributes[:subscription_id] = get_non_blank("Subscription Id")
      attributes[:tenant_id] = get_non_blank("Tenant Id")
      attributes[:security_id] = get_non_blank("Azure Client Id")
      attributes[:security_key] = get_non_blank("Client Secret")
      valid = false
      while !valid
        print "Filtering level (resource group/subscription): "
        response = STDIN.gets.strip.downcase
        if ["resource group", "subscription"].include?(response)
          valid = true
          attributes[:filter_level] = response
        else
          puts "Invalid selection. Please enter resource group or subscription"
        end
      end
      attributes[:resource_groups] = []
      if attributes[:filter_level] == "resource group"
        attributes[:resource_groups] << get_non_blank("First resource group name", "Resource group").downcase
        stop = false
        while !stop
          valid = false
          while !valid
            print "Additional resource groups (y/n)? "
            response = STDIN.gets.chomp.downcase.strip
            if response == "n"
              stop = true
              valid = true
            elsif response == "y"
              valid = true
            else
             puts "Invalid response. Please try again"
            end
          end
          if !stop
            attributes[:resource_groups] << get_non_blank("Additional resource group name", "Resource group").downcase
          end
        end
      end
    end
  
    project = Project.new(attributes)
    valid = project.valid?
    while !valid
      project.errors.messages.each do |k, v|
        puts "#{k} #{v.join("; ")}"
        puts "Please enter new #{k}"
        value = get_non_blank(k)
        project.write_attribute(k, value)
      end
      valid = project.valid?
    end
    project.save

    #Budget.create(project_id: project.id, amount: budget, effective_at: project.start_date, timestamp: Time.now)
    puts "Project #{project.name} created"
  
    # credentials = nil
    # valid = false
    # while !valid
    #   print "Validate credentials (y/n)? "
    #   response = STDIN.gets.chomp.downcase.strip
    #   if response == "n"
    #     valid = true
    #   elsif response == "y"
    #     valid = true
    #     credentials = validate_credentials(project)
    #   else
    #     puts "Invalid response. Please try again"
    #   end
    # end

    # if credentials != false && Date.parse(project.start_date) < Project::DEFAULT_DATE
    #   valid = false
    #   while !valid
    #     print "Project start date is in the past. Would you like to retrieve and record historic costs (y/n)? "
    #     print "This may take a long time (5+ mins per month of data). " if project.azure?
    #     response = STDIN.gets.chomp.downcase.strip
    #     if response == "n"
    #       stop = true
    #       valid = true
    #     elsif response == "y"
    #       "Recording logs"
    #       valid = true
    #       project = ProjectFactory.new().as_type(project)
    #       begin
    #         project.record_logs_for_range(Date.parse(project.start_date), Project::DEFAULT_DATE - 1.day)
    #       rescue AzureApiError, AwsSdkError => e
    #         puts "Generation of logs for project #{project.name} stopped due to error: "
    #         puts e
    #         return
    #       end
    #       puts "Logs recorded."
    #     else
    #       puts "Invalid response. Please try again"
    #     end
    #   end
    # end
  end

# def validate_credentials(project)
#   project = @factory.as_type(project)
#   project.validate_credentials
# end

# def add_budget(project)
#   valid = false
#   while !valid
#     amount = get_non_blank("Budget amount (c.u./month)", "Budget")
#     valid = begin
#       Integer(amount, 10)
#     rescue ArgumentError, TypeError
#       false
#     end
#     puts "Please enter a number" if !valid
#   end

#   valid_date = false
#   while !valid_date
#     print "Effective at (YYYY-MM-DD): "
#     valid_date = begin
#       Date.parse(STDIN.gets.chomp.strip)
#     rescue ArgumentError
#       false
#     end
#     puts "Invalid date. Please ensure it is in the format YYYY-MM-DD" if !valid_date
#   end
#   budget = Budget.new(project_id: project.id, amount: amount, effective_at: valid_date, timestamp: Time.now)
#   budget.save!
#   puts "Budget created"
# end

  def get_non_blank(text, attribute=text, options=nil)
    valid = false
    while !valid
      print "#{text}"
      print "(#{options})" if options
      print ": "
      response = STDIN.gets.strip
      if response.empty?
        puts "#{attribute} must not be blank"
      else
        valid = true
      end
    end
    response
  end

  def show_attributes(project) 
    puts project.name
    puts "platform: #{project.platform}"
    puts "start_date: #{project.start_date}"
    puts "end_date: #{project.end_date}"
    puts "archived: #{project.archived}"
    puts "visualiser: #{project.visualiser}"
    #puts "budget: #{project.current_budget}c.u./month"
    puts "filter_level: #{project.filter_level}"
    puts "slack_channel: #{project.slack_channel}"
    show_class_specific_fields(project)
  end

  def show_class_specific_fields(project)
    if project.type == "AwsProject"
      puts "regions: #{project.regions.join(", ")}"
      puts "project_tag: #{project.project_tag}" if project.filter_level == "tag"
      puts "access_key_ident: hidden"
      puts "key: hidden"
    else
      puts "resource_groups: #{project.resource_groups.join(", ")}" if project.filter_level == "resource group"
      puts "subscription_id: #{project.subscription_id}"
      puts "tenant_id: #{project.tenant_id}"
      puts "azure_client_id: hidden"
      puts "client_secret: hidden"
    end
  end

  # for table print
  class NoMethodMissingFormatter
    def format(value)
      value == "Method Missing" ? "n/a" : value
    end
  end
end
