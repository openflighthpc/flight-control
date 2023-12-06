require_relative '../models/example_project'
require_relative 'example_errors'
require_relative 'request_generator'

class ExampleInstanceDetailsRecorder
  @@region_mappings = {}
  @@regions_file = nil

  def self.regions_file
    @@regions_file ||= File.join(Rails.root, 'lib', 'platform_files', 'example_region_names.txt')
  end

  def initialize(project)
    @project = project
    determine_region_mappings
  end

  def record
    database_entries = {}
    regions.each do |region|
      results = nil

      models = JSON.parse(http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/model-details').body)
      response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/model-details',
                              headers: {'Project-Credentials' => {'PROJECT_NAME': @project.name}.to_json},
                              body: { "models" => models.join(',') }.to_json
                             )
      raise ExampleApiError, "Couldn't obtain instance details" unless response.code == "200"

      database_entries[region] ||= []
      JSON.parse(response.body).each do |model|
        attributes = details["product"]["attributes"]
        next unless instance_types.include?(model["model"])

        info = {
          instance_type: model["model"],
          region: region,
          platform: "example",
          currency: model["currency"],
          price_per_hour: model["price_per_hour"],
          cpu: model["cpu"].to_i,
          gpu: model["gpu"].to_i,
          mem: model["mem"].to_i,
        }
        if info[:instance_type] && info[:region]
          existing_details = InstanceTypeDetail.find_by(instance_type: info[:instance_type], region: info[:region])
          if existing_details
            existing_details.update!(info)
          else
            InstanceTypeDetail.create!(info)
          end
        else
          Rails.logger.error("Instance details not saved due to missing region and/or instance type.")
        end
        database_entries[region].append(attributes["instanceType"])
      end
    end
    keep_only_updated_entries(database_entries) if database_entries
  end

  def validate_credentials
    response = http_request(uri: 'http://0.0.0.0:4567/providers/example-provider/validate-credentials',
                            request_type: "post",
                            headers: {'Project-Credentials' => {'PROJECT_NAME': @project.name}.to_json}
                           )
    response.code=="200"
  end

  private

  def regions
    if !@regions
      @regions = ["Mars", "Metaverse"]
      @regions.sort!
    end
    @regions
  end

  def instance_types
    @instance_types ||= InstanceLog.where(platform: "example").pluck(Arel.sql("DISTINCT instance_type"))
  end

  def determine_region_mappings
    if @@region_mappings == {}
      file = File.open(self.class.regions_file)
      file.readlines.each do |line|
        line = line.split(",")
        @@region_mappings[line[0]] = line[1].strip
      end
    end
  end

  def keep_only_updated_entries(updated_entries)
    InstanceTypeDetail.where(platform: 'example').each do |details|
      region = details.region.to_s
      instance_type = details.instance_type.to_s
      unless updated_entries[region] && updated_entries[region].include?(instance_type)
        Rails.logger.error("Database entry for region: #{region} and instance type: #{instance_type} was not updated and will be deleted.")
        InstanceTypeDetail.find_by(instance_type: instance_type, region: region).destroy
      end
    end
  end
end
