require 'securerandom'

namespace :users do
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
      #{result[:user].errors.full_messages.join('\n')}
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
    users = User.all.map { |u| {username: u.username, status: u.active? ? 'active' : 'archived' } }
    tp users
  end

  desc "Show user status"
  task :status, [:username] => :environment do |task, args|
    arguments = args.to_h
    user = User.find_by(username: arguments[:username])
    tp user.map { |u| { username: u.username, status: u.active? ? 'active' : 'archived' } }
  end
end

def create(username, password=nil)
  pass ||= SecureRandom.base58(10)

  return {
    user: User.create(username: username, password: pass, password_confirmation: pass),
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
