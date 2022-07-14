require_relative 'azure_service'
require_relative '../models/instance_log'

class AzureInstanceDetailsRecorder < AzureService
  @@region_mappings = {}
  @@prices_file = nil
  @@sizes_file = nil
  @@regions_file = nil

  def self.prices_file
    @@prices_file ||= File.join(Rails.root, 'lib', 'platform_files', 'azure_instance_prices.txt')
  end

  def self.sizes_file
    @@sizes_file ||= File.join(Rails.root, 'lib', 'platform_files', 'azure_instance_sizes.txt')
  end

  def self.regions_file
    @@regions_file ||= File.join(Rails.root, 'lib', 'platform_files', 'azure_region_names.txt')
  end

  # The new Azure Prices API allows filters, but only includes 100 records per
  # request. As 2 responses per instance type (linux and windows, which can't
  # be filtered out in the query), if more than 50 instance types in a region
  # logic will need updating to make further requests to get subsquent records.
  def record
    size_info = get_instance_sizes
    regions.each do |region|
      regional_price_details = get_regional_instance_prices(region)
      unless regional_price_details.empty?
        regional_price_details.values.each do |details|
          info = {
            instance_type: details["meterName"],
            region: details["armRegionName"],
            price_per_hour: details["unitPrice"],
            currency: details["currencyCode"],
          }.merge(size_info)
          InstanceTypeDetail.new(info).record_details
        end
      end
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

      if response.success?
        File.write(self.class.sizes_file, "#{Time.current}\n")
        response["value"].each do |instance|
          if instance["resourceType"] == "virtualMachines" && regions.include?(instance["locations"][0]) &&
            instance_types.include?(instance["name"])
            size_info = {
              instance_type: instance["name"], instance_family: instance["family"],
              location: instance["locations"][0],
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
          end
        end
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
        size_info = {
          mem: -1,
          cpu: -1,
          gpu: -1,
        }
      end
    end
    size_info
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
end
