class ComputeGroupConfigsController < ApplicationController
  def update
    get_project
    success = nil
    permitted_params["groups"].each do |group_id, details|
      group = @project.compute_group_configs.find(group_id)
      group.update_attributes(details)
      success = group.save
      if !success
        flash[:error] = "Cannot update config: #{group.errors.full_messages.join("; ")}"
        break
      end
    end
    flash[:success] = "Compute group config updated" if success
    redirect_to policies_path(project: @project.name)
  end

  private

  def permitted_params
    params.permit(
      groups: [
        :priority,
        :colour,
        :storage_colour,
        instance_type_configs_attributes: [:priority, :id],
      ],
    )
  end
end
