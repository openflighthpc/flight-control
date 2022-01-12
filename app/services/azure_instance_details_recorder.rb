require_relative 'azure_service'

class AzureInstanceDetailsRecorder < AzureService

  def record
    record_instance_prices
    record_instance_sizes
  end

  def record_instance_prices
  end

  def record_instance_sizes
    regions = InstanceLog.where(platform: "azure").select(:region).distinct.pluck(:region) | ["uksouth"]
    regions.sort!

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
  
  def sizes_file
    @file ||= File.join(Rails.root, 'lib', 'platform_files', 'azure_instance_sizes.txt')
  end
end
