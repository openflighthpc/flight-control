require 'securerandom'

namespace :users do
  namespace :roles do
    desc "Assign a role"
    task :assign, [:username, :project, :role] => :environment do |task, args|
      arguments = args.to_h

      user = User.find_by(username: arguments[:username])
      project = Project.find_by(name: arguments[:project])

      unless user
        puts "User #{arguments[:username]} not found."
        next
      end

      unless project
        puts "Project #{arguments[:project]} not found."
        next
      end

      role = assign_role(user, project, arguments[:role])

      if role.valid?
        puts "User #{user.username} now has '#{role.role}' role for project #{project.name}"
      else
        puts "Error creating user role:\n #{role.errors.full_messages.join("\n")}"
      end
    end

    desc "Revoke a role"
    task :revoke, [:username, :project, :role] => :environment do |task, args|
      arguments = args.to_h

      user = User.find_by(username: arguments[:username])
      project = Project.find_by(name: arguments[:project])

      unless user
        puts "User #{arguments[:username]} not found."
        next
      end

      unless project
        puts "Project #{arguments[:project]} not found."
        next
      end

      role = UserRole.find_by(user: user, project: project, role: arguments[:role])

      unless role
        puts "Given role does not exist"
        next
      end

      if role.destroy
        puts "Role revoked."
      else
        "Error revoking role:\n #{role.errors.full_messages}"
      end
    end
  end

  desc "Create a local user entity"
  task :create, [:username, :password] => :environment do |task, args|
    arguments = args.to_h

    result = create(arguments[:username], arguments[:password])

    if result[:user].valid?
      puts <<~OUT
      User created:
      Name: #{arguments[:username]}
      Password: #{result[:pass]}
      OUT
    else
      puts <<~OUT
      Error when creating user:
      #{result[:user].errors.full_messages.join("\n")}
      OUT
    end
  end

  desc "Reset a user's password"
  task :reset_pass, [:username, :password] => :environment  do |task, args|
    arguments = args.to_h

    result = reset_pass(arguments[:username], arguments[:password])

    if result[:user]&.valid?
      puts <<~OUT
      User \"#{arguments[:username]}\" password reset.
      Password: #{result[:password]}
      OUT
    elsif !result[:user].nil?
      puts <<~OUT
      Error when updating password:
      #{result[:user].errors.full_messages.join('\n')}
      OUT
    end
  end

  desc "Archive a user"
  task :archive, [:username] => :environment do |task, args|
    arguments = args.to_h

    if archive(arguments[:username])
      puts "User \"#{arguments[:username]}\" archived"
    end
  end

  desc "Un-archive a user"
  task :activate, [:username] => :environment do |task, args|
    arguments = args.to_h

    if activate(arguments[:username])
      puts "User \"#{arguments[:username]}\" activated"
    end
  end

  desc "List users"
  task :list => :environment do
    puts "Admin users:\n\n"

    tp User.where(admin: true), :username, :active?

    puts "\nNon-admin users:\n\n"

    tp User.where(admin: false),
      "username",
      :active?,
      {"projects.name" => {display_name: "projects"}},
      {"user_roles.role" => {display_name: "roles"}}
  end

  desc "Show user status"
  task :status, [:username] => :environment do |task, args|
    arguments = args.to_h
    user = [User.find_by(username: arguments[:username])]
    tp user, :username, :active?
  end

  desc "Set admin status of user"
  task :set_admin_status, [:username, :bool] => :environment do |task, args|
    arguments = args.to_h

    user = set_admin_status(arguments[:username], arguments[:bool])
    if user.valid?
      user.save
      puts "User \"#{arguments[:username]}\" admin status is now '#{user.admin?}'"
    else
      puts "Error changing user admin status:\n #{user.errors.full_messages.join("\n")}"
    end
  end
end

def assign_role(user, project, role)
  return UserRole.create(user: user, project: project, role: role)
end

def set_admin_status(username, bool)
  user = User.find_by(username: username)

  unless user
    puts "User not found"
    return
  end

  user.admin = bool == 'true'

  return user
end

def create(username, pass=nil)
  pass ||= SecureRandom.base58(10)

  return {
    user: User.create(username: username, password: pass, password_confirmation: pass, admin: false),
    pass: pass
  }
end

def archive(username)
  user = User.find_by(username: username)
  unless user
    puts "User not found"
    return {user: nil}
  end

  if user.archived?
    puts "User is already archived"
    return
  end

  return user.archive
end

def reset_pass(username, password=nil)
  password ||= SecureRandom.base58(10)
  user = User.find_by(username: username)

  unless user
    puts "User not found"
    return {}
  end

  user.password = password
  user.save

  return {
    user: user,
    password: password
  }
end

def activate(username)
  user = User.find_by(username: username)
  unless user
    puts "User not found"
    return
  end

  if user.active?
    puts "User is already active"
    return
  end

  return user.activate
end
