# frozen_string_literal: true

class AddInitialInstanceMappings < ActiveRecord::Migration[6.0]
  def up
    mappings.each do |platform, mappings|
      mappings.each do |type, customer_facing|
        InstanceMapping.create(platform: platform,
                               instance_type: type,
                               customer_facing_type: customer_facing
                              )
      end
    end
  end

  def down
    mappings.each do |platform, mappings|
      InstanceMapping.where("instance_type IN (?)", mappings.keys).delete_all
    end
  end

  def mappings
    {
      "aws" => {
        "t3.medium" => "General (Small)",
        "t3.xlarge" => "General (Medium)",
        "t3.2xlarge" => "General (Large)",
        "c5.large" => "Compute (Small)",
        "c5.xlarge" => "Compute (Medium)",
        "c5.2xlarge" => "Compute (Large)",
        "p3.2xlarge" => "GPU (Small)",
        "p3.8xlarge" => "GPU (Medium)",
        "p3.16xlarge" => "GPU (Large)",
        "r5.large" => "Mem (Small)",
        "r5.xlarge" => "Mem (Medium)",
        "r5.2xlarge" => "Mem (Large)"
      },
      "azure" => {
        "Standard_F2s_v2" => "Compute (Small)",
        "Standard_F4s_v2" => "Compute (Medium)",
        "Standard_F8s_v2" => "Compute (Large)",
        "Standard_NC6s_v3" => "GPU (Small)",
        "Standard_E2_v4" => "Mem (Small)",
        "Standard_E4_v4" => "Mem (Medium)",
        "Standard_E8_v2" => "Mem (Large)",
        "Standard_B2s" => "General (Small)",
        "Standard_HC44rs" => "Infiniband (Standard)",
        "Standard_E8_v4" => "Mem (Large)",
        "Standard_DS1_v2" => "Test (Small)",
        "Standard_NC24s_v3" => "GPU (Large)",
        "Standard_NC12s_v3" => "GPU (Medium)",
        "Standard_ND96asr_v4" => "GPU (A100)",
        "Standard_HB120rs_v3" => "Infiniband (Large)",
        "Standard_E32ads_v5" => "Memory (Large)"
      },
      "example" => {
        "mining_rig" => "Mining Rig",
        "compute_small" => "Compute (Small)",
        "compute_large" => "Compute (Large)"
      }
    }
  end
end
