class ComputeGroupConfigsController < ApplicationController
  def update
    get_project
    if !@project
      no_project_redirect
    else
      success = nil
      authorize @project, :config_update?, policy_class: ProjectPolicy
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
  end

  def regenerate
    get_project
    if !@project
      no_project_redirect
    else
      authorize @project, :config_update?, policy_class: ProjectPolicy
      result = @project.create_config(true)
      if result["error"]
        flash[:error] = result["error"]
      elsif result["changed"]
        flash[:success] = "Config updated: "
        flash[:success] << result.select {|k, v| v && k != "changed" }.keys.join(", ")
      else
        flash[:alert] = "No changes to config"
      end
      redirect_to policies_path(project: @project.name)
    end
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
