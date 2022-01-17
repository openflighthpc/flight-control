require_relative 'azure_service'
require_relative '../models/instance_log'

class AzureInstanceDetailsRecorder < AzureService
  @@region_mappings = {}

  def record
    record_instance_prices
    record_instance_sizes
  end

  # The new Azure Prices API allows filters, but only includes 100 records per
  # request. As 2 responses per instance type (linux and windows, which can't
  # be filtered out in the query), if more than 50 instance types in a region
  # logic will need updating to make further requests to get subsquent records.
  def record_instance_prices
    first_query = true
    regions_and_types.each do |region, types|
      types_filter = ""
      types.each_with_index do |type, index|
        types_filter << "#{index == 0 ? "" : "or"} armSkuName eq '#{type}'"
      end

      uri = "https://prices.azure.com/api/retail/prices?currencyCode='GBP'&$filter=serviceName eq 'Virtual Machines' and armRegionName eq '#{region}' and priceType eq 'Consumption' and (#{types_filter})"
      response = HTTParty.get(uri, timeout: DEFAULT_TIMEOUT)
      if response.success?
        if first_query
          File.write(prices_file, "#{Time.now}\n")
          first_query = false
        end
        matches = response["Items"].select do |price|
          price["isPrimaryMeterRegion"] && !price["productName"].end_with?("Windows")
        end
        matches.each do |matched|
          File.write(prices_file, matched.to_json, mode: "a")
          File.write(prices_file, "\n", mode: "a")
        end
      end
    end
  end

  # The skus API does have a filter option, but only for location and only for one
  # location at a time. Currently more efficient to get for all locations and filter locally.
  def record_instance_sizes
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
        File.write(sizes_file, "#{Time.now}\n")
        response["value"].each do |instance|
          if instance["resourceType"] == "virtualMachines" && regions.include?(instance["locations"][0]) &&
            instance_types.include?(instance["name"])
            details = {
              instance_type: instance["name"], instance_family: instance["family"],
              location: instance["locations"][0],
              cpu: 0, gpu: 0, mem: 0
            }

            instance["capabilities"].each do |capability|
              if capability["name"] == "MemoryGB"
                details[:mem] = capability["value"].to_f
              elsif capability["name"] == "vCPUs"
                details[:cpu] = capability["value"].to_i
              elsif capability["name"] == "GPUs"
                details[:gpu] = capability["value"].to_i
              end
            end
            File.write(sizes_file, details.to_json, mode: "a")
            File.write(sizes_file, "\n", mode: "a")
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
        raise error
      end
    end
    true
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

  def prices_file
    @prices_file ||= File.join(Rails.root, 'lib', 'platform_files', 'azure_instance_prices.txt')
  end

  def sizes_file
    @sizes_file ||= File.join(Rails.root, 'lib', 'platform_files', 'azure_instance_sizes.txt')
  end

  def instance_types
    @instance_types ||= InstanceLog.where(platform: "azure").pluck(Arel.sql("DISTINCT instance_type"))
  end

  def regions
    @regions ||= (InstanceLog.where(platform: "azure").pluck(Arel.sql("DISTINCT region")) | ["uksouth"])
  end

  def regions_and_types
    if !@regions_and_types
      @regions_and_types = {}
      regions.each do |region|
        types = InstanceLog.where(platform: "azure", region: region).pluck(Arel.sql("DISTINCT instance_type"))
        regions_and_types[region] = types
      end
    end
    @regions_and_types
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
      file = File.open(File.join(Rails.root, 'lib', 'platform_files', 'azure_region_names.txt'))
      file.readlines.each do |line|
        line = line.split(",")
        @@region_mappings[line[0]] = line[1].strip
      end
    end
    region_mappings
  end
end
