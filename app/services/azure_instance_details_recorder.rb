require_relative 'azure_service'

class AzureInstanceDetailsRecorder < AzureService
  @@region_mappings = {}

  def record
    determine_region_mappings
    record_instance_prices
    record_instance_sizes
  end

  def record_instance_prices
    timestamp = begin
      Date.parse(File.open(prices_file).first) 
    rescue ArgumentError, Errno::ENOENT
      false
    end
    existing_regions = begin
      File.open(prices_file).first(2).last.chomp
    rescue Errno::ENOENT 
      false
    end
    if timestamp == false || Date.today - timestamp >= 1 || existing_regions == false || existing_regions != mapped_regions.to_s
      uri = "https://management.azure.com/subscriptions/#{@project.subscription_id}/providers/Microsoft.Commerce/RateCard?api-version=2016-08-31-preview&$filter=OfferDurableId eq 'MS-AZR-0003P' and Currency eq 'GBP' and Locale eq 'en-GB' and RegionInfo eq 'GB'"
      attempt = 0
      error = AzureApiError.new("Timeout error obtaining latest Azure price list."\
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
          File.write(prices_file, "#{Time.now}\n")
          File.write(prices_file, "#{mapped_regions}\n", mode: "a")
          response['Meters'].each do |meter|
            if mapped_regions.include?(meter['MeterRegion']) && meter['MeterCategory'] == "Virtual Machines" &&
              !meter['MeterName'].downcase.include?('low priority') &&
              !meter["MeterSubCategory"].downcase.include?("windows")
              File.write(prices_file, meter.to_json, mode: "a")
              File.write(prices_file, "\n", mode: "a")
            end
          end
        elsif response.code == 504
          raise Net::ReadTimeout
        else
          raise AzureApiError.new("Error obtaining latest Azure price list. Error code #{response.code}.\n#{response}")
        end
      rescue Net::ReadTimeout
        msg = "Attempt #{attempt}: Request timed out.\n"
        if response
          msg << "Error code #{response.code}.\n#{response}\n"
        end
        error.error_messages.append(msg)
        if attempt < MAX_API_ATTEMPTS
          retry
        else
          raise error
        end
      end
    end
  end

  def record_instance_sizes
    timestamp = begin
      Date.parse(File.open(sizes_file).first) 
    rescue ArgumentError, Errno::ENOENT
      false
    end
    existing_regions = begin
      File.open(sizes_file).first(2).last.chomp
    rescue Errno::ENOENT 
      false
    end

    if timestamp == false || Date.today - timestamp >= 1 || existing_regions == false || existing_regions != regions.to_s
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
          File.write(sizes_file, "#{regions}\n", mode: "a")
          response["value"].each do |instance|
            if instance["resourceType"] == "virtualMachines" && regions.include?(instance["locations"][0]) &&
              instance["name"].include?("Standard")
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
    end
  end

  private

  def prices_file
    @prices_file ||= File.join(Rails.root, 'lib', 'platform_files', 'azure_instance_prices.txt')
  end

  def sizes_file
    @sizes_file ||= File.join(Rails.root, 'lib', 'platform_files', 'azure_instance_sizes.txt')
  end

  def regions
    @regions ||= (InstanceLog.where(platform: "azure").select(:region).distinct.pluck(:region) | ["uksouth"]).sort
  end

  def mapped_regions
    @mapped_regions ||= regions.map do |region|
      value = @@region_mappings[region]
      puts "No region mapping for #{region}, please update 'azure_region_names.txt' and rerun" and return if !value
      value
    end
  end

  def determine_region_mappings
    if @@region_mappings == {}
      file = File.open(File.join(Rails.root, 'lib', 'platform_files', 'azure_region_names.txt'))
      file.readlines.each do |line|
        line = line.split(",")
        @@region_mappings[line[0]] = line[1].strip
      end
    end
  end
end
