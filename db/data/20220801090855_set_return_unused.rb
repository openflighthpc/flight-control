# frozen_string_literal: true

class SetReturnUnused < ActiveRecord::Migration[6.0]
  def up
    FundsTransferRequest.where(action: "send").each do |request|
      request.return_unused = true
      request.save!
    end
  end

  def down
    FundsTransferRequest.all.each do |request|
      request.return_unused = nil
      request.save!
    end
  end
end
