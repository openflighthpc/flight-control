require_relative '../models/aws_project'
require_relative 'aws_sdk_error'
require 'aws-sdk-pricing'

class AwsInstanceDetailsRecorder
  @@region_mappings = {}

  def initialize(project)
    @project = project
    Aws.config.update({region: "us-east-1"})
    @pricing_checker = Aws::Pricing::Client.new(access_key_id: @project.access_key_ident, secret_access_key: @project.key)
    determine_region_mappings
  end

  def record
    regions.each.with_index do |region, index|
      if index == 0
        File.write(details_file, "#{Time.now}\n")
      end
      first_query = true
      results = nil
      while first_query || results&.next_token
        begin
          results = @pricing_checker.get_products(instances_info_query(region, results&.next_token))
        rescue Aws::Pricing::Errors::ServiceError, Aws::Errors::MissingRegionError, Seahorse::Client::NetworkingError => error
          raise AwsSdkError.new("Unable to determine AWS instances in region #{region}. #{error}")
        end
        results.price_list.each do |result|
          details = JSON.parse(result)
          attributes = details["product"]["attributes"]
          next if !instance_types.include?(attributes["instanceType"])

          price = details["terms"]["OnDemand"]
          price = price[price.keys[0]]["priceDimensions"]
          price = price[price.keys[0]]["pricePerUnit"]["USD"].to_f
          mem = attributes["memory"].gsub(" GiB", "")
          info = {
            instance_type: attributes["instanceType"],
            location: region, 
            price_per_hour: price,
            cpu: attributes["vcpu"].to_i,
            mem: mem.to_f,
            gpu: attributes["gpu"] ? attributes["gpu"].to_i : 0
          }
          File.write(details_file, "#{info.to_json}\n", mode: 'a')
        end
        first_query = false
      end
    end
  end

  def validate_credentials
    valid = true
    begin
      @pricing_checker.get_products(instances_info_query(@project.regions.first))
    rescue => error
      puts "Unable to obtain instance pricing and sizes data: #{error}"
      valid = false
    end
    valid
  end

  private

  def regions
    if !@regions
      @regions = AwsProject.all.pluck(:regions).flatten.uniq | ["eu-west-2"]
      @regions.sort!
    end
    @regions
  end

  def instance_types
    @instance_types ||= instance_types = InstanceLog.where(platform: "aws").pluck(Arel.sql("DISTINCT instance_type"))
  end
  
  def instances_info_query(region, token=nil)
    details = {
      service_code: "AmazonEC2",
      filters: [ 
        {
          field: "location", 
          type: "TERM_MATCH", 
          value: @@region_mappings[region], 
        },
        {
          field: "tenancy",
          type: "TERM_MATCH",
          value: "shared"
        },
        {
          field: "capacitystatus",
          type: "TERM_MATCH",
          value: "UnusedCapacityReservation"
        },
        {
          field: "operatingSystem",
          type: "TERM_MATCH",
          value: "linux"
        },
        {
          field: "preInstalledSW",
          type: "TERM_MATCH", 
          value: "NA"
        }
     ], 
     format_version: "aws_v1"
    }
    details[:next_token] = token if token
    details
  end

  def details_file
    @file ||= File.join(Rails.root, 'lib', 'platform_files', 'aws_instance_details.txt')
  end

  def determine_region_mappings
    if @@region_mappings == {}
      file = File.open(File.join(Rails.root, 'lib', 'platform_files', 'aws_region_names.txt'))
      file.readlines.each do |line|
        line = line.split(",")
        @@region_mappings[line[0]] = line[1].strip
      end
    end
  end
end
