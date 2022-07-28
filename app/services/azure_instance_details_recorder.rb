require_relative 'azure_service'
require_relative '../models/instance_log'

class AzureInstanceDetailsRecorder < AzureService
  @@region_mappings = {}
  @@regions_file = nil

  def self.regions_file
    @@regions_file ||= File.join(Rails.root, 'lib', 'platform_files', 'azure_region_names.txt')
  end

  # The new Azure Prices API allows filters, but only includes 100 records per
  # request. As 2 responses per instance type (linux and windows, which can't
  # be filtered out in the query), if more than 50 instance types in a region
  # logic will need updating to make further requests to get subsequent records.
  def record
    failed_query = false
    database_entries = {}

    size_details = get_instance_sizes
    if size_details
      size_details.each do |info|
        if info[:instance_type] && info[:region]
          record_details_to_database(info)
        else
          Rails.logger.error("Instance size details not saved due to missing region and/or instance type.")
          failed_query = true
        end
        unless failed_query
          database_entries[info[:region]] = [] if database_entries[info[:region]].nil?
          database_entries[info[:region]].append(info[:instance_type])
        end
      end
    else
      Rails.logger.error("Error obtaining latest Azure instance size details.")
      failed_query = true
      database_entries = nil
    end

    regions.each do |region|
      database_entries[region] ||= [] unless failed_query
      regional_price_details = get_regional_instance_prices(region)
      if regional_price_details
        regional_price_details.each do |type, details|
          if details.empty?
            Rails.logger.error("No valid data for region: #{region}, instance type: #{type}")
          else
            info = {
              instance_type: details["armSkuName"],
              region: details["armRegionName"],
              platform: "azure",
              price_per_hour: details["unitPrice"],
              currency: details["currencyCode"],
            }
            if info[:instance_type] && info[:region]
              record_details_to_database(info)
            else
              Rails.logger.error("Instance size details not saved due to missing region and/or instance type.")
              failed_query = true
            end
            database_entries[region].append(info[:instance_type]) unless failed_query
          end
        end
      else
        Rails.logger.error("Error obtaining latest Azure instance pricing details for region: #{region}")
        failed_query = true
        database_entries = nil
      end
    end
    keep_only_updated_entries(database_entries) if database_entries
  end

  def record_details_to_database(info)
    existing_details = InstanceTypeDetail.find_by(instance_type: info[:instance_type], region: info[:region])
    if existing_details
      existing_details.update!(info)
    else
      InstanceTypeDetail.create!(info)
    end
  end

  def get_regional_instance_prices(region)
    matches = {}
    uri = "https://prices.azure.com/api/retail/prices?currencyCode='GBP'&$filter=serviceName eq 'Virtual Machines' and armRegionName eq '#{region}' and priceType eq 'Consumption' and (#{types_filter})"
    response = HTTParty.get(uri, timeout: DEFAULT_TIMEOUT)
    if response.success?
      response["Items"].each do |price|
        if !price["productName"].end_with?("Windows") &&
          !price["skuName"].end_with?("Low Priority") &&
          !price["skuName"].end_with?("Spot")
          type = price["armSkuName"]
          if matches[type]
            # The API sometimes returns more than one price for the same type,
            # but with different date. We only want the most recent.
            more_recent = Time.parse(price["effectiveStartDate"]) > Time.parse(matches[type]["effectiveStartDate"])
            matches[type] = price if more_recent
          else
            matches[type] = price
          end
        end
      end
    end
    matches
  end

  # The skus API does have a filter option, but only for location and only for one
  # location at a time. Currently more efficient to get for all locations and filter locally.
  def get_instance_sizes
    uri = "https://management.azure.com/subscriptions/#{@project.subscription_id}/providers/Microsoft.Compute/skus?api-version=2019-04-01"
    attempt = 0
    error = AzureApiError.new("Timeout error obtaining latest Azure instance list."\
                              "All #{MAX_API_ATTEMPTS} attempts timed out.")
    begin
      @project.authoriser.refresh_auth_token
      attempt += 1
      response = HTTParty.get(
        uri,
        headers: { 'Authorization': "Bearer #{@project.bearer_token}" },
        timeout: DEFAULT_TIMEOUT
      )
      instance_details = []

      if response.success?
        response["value"].each do |instance|
          if instance["resourceType"] == "virtualMachines" && regions.include?(instance["locations"][0]) &&
            instance_types.include?(instance["name"])
            size_info = {
              instance_type: instance["name"],
              region: instance["locations"][0],
              cpu: 0, gpu: 0, mem: 0
            }

            instance["capabilities"].each do |capability|
              if capability["name"] == "MemoryGB"
                size_info[:mem] = capability["value"].to_f
              elsif capability["name"] == "vCPUs"
                size_info[:cpu] = capability["value"].to_i
              elsif capability["name"] == "GPUs"
                size_info[:gpu] = capability["value"].to_i
              end
            end
            instance_details.append(size_info)
          end
        end
        return instance_details
      elsif response.code == 504
        raise Net::ReadTimeout
      else
        raise AzureApiError.new("Error obtaining latest Azure instance list. Error code #{response.code}.\n#{response if @verbose}")
      end
    rescue Net::ReadTimeout
      msg = "Attempt #{attempt}: Request timed out.\n"
      if response
        msg << "Error code #{response.code}.\n#{response if @verbose}\n"
      end
      error.error_messages.append(msg)
      if attempt < MAX_API_ATTEMPTS
        retry
      else
        raise error
      end
    end
  end

  # only recording instance sizes requires authorisation
  def validate_credentials
    valid = true
    begin
      uri = "https://management.azure.com/subscriptions/#{@project.subscription_id}/providers/Microsoft.Compute/skus?api-version=2019-04-01"
      @project.authoriser.refresh_auth_token
      response = HTTParty.get(
        uri,
        headers: { 'Authorization': "Bearer #{@project.bearer_token}" },
        timeout: DEFAULT_TIMEOUT
      )
    rescue => error
      puts "Unable to access instance sizes data: #{error}"
      valid = false
    end
    valid
  end

  private

  def types_filter
    @types_filter ||= "".tap do |tf|
      instance_types.each_with_index do |type, index|
        tf << "#{index == 0 ? "" : " or"} armSkuName eq '#{type}'"
      end
    end
  end

  def instance_types
    @instance_types ||= InstanceLog.where(platform: "azure").pluck(Arel.sql("DISTINCT instance_type"))
  end

  def regions
    @regions ||= (InstanceLog.where(platform: "azure").pluck(Arel.sql("DISTINCT region")) | ["uksouth"])
  end

  def mapped_regions
    @mapped_regions ||= regions.map do |region|
      value = region_mappings[region]
      puts "No region mapping for #{region}, please update 'azure_region_names.txt' and rerun" and return if !value
      value
    end
  end

  def region_mappings
    if @@region_mappings == {}
      file = File.open(self.class.regions_file)
      file.readlines.each do |line|
        line = line.split(",")
        @@region_mappings[line[0]] = line[1].strip
      end
    end
    region_mappings
  end

  def keep_only_updated_entries(updated_entries)
    InstanceTypeDetail.where(platform: 'azure').each do |details|
      region = details.region.to_s
      instance_type = details.instance_type.to_s
      unless updated_entries[region] && updated_entries[region].include?(instance_type)
        Rails.logger.error("Database entry for region: #{region} and instance type: #{instance_type} was not updated and will be deleted.")
        details.destroy
      end
    end
  end
end
