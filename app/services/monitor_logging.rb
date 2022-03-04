require 'logger'

module MonitorLogging

  def setup_logger(grouping)
    log_dir = File.join(Rails.root, 'log', 'monitor', @project.name)
    log_prefix = [@project.name, @project.platform, grouping].compact.join('_')

    FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)

    logs = get_logs(log_dir, log_prefix)
    until logs.count <= 71
      File.delete(logs.first) if File.exist?(logs.first)
      logs = get_logs(log_dir, log_prefix)
    end

    return Logger.new(File.join(log_dir, "#{log_prefix}_#{Time.now.strftime("%d-%m-%Y_%H-%M-%S")}.log"))
  end

  def get_logs(log_dir, log_prefix)
    Dir[File.join(log_dir, "#{log_prefix}*.log")].sort_by { |f| File.mtime(f) }
  end
end
