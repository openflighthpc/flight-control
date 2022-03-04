require 'securerandom'

namespace :users do
  desc "Create a local user entity"
  task :create, [:username] => :environment do |task, args|
    arguments = args.to_h

    result = create(arguments[:username])

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

  desc "Archive a user"
  task :archive, [:username] => :environment do |task, args|
    arguments = args.to_h

    if archive(arguments[:username])
      puts "User \"#{arguments[:username]}\" archived"
    end
  end

end

def create(username)
  pass = SecureRandom.base58(10)

  return {
    user: User.create(username: username, password: pass, password_confirmation: pass),
    pass: pass
  }
end

def archive(username)
  user = User.find_by(username: username)
  unless user
    puts "User not found"
    return
  end

  if user.archived?
    puts "User is already archived"
    return
  end

  return user.archive
end
