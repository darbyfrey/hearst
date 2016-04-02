require 'eventmachine'

namespace :hearst do

  desc 'Create a queue and listen for messages'
  task listen: :environment do
    EventMachine.run {
      Signal.trap('INT') do
        EM::stop()
      end

      Signal.trap('TERM') do
        EM::stop()
      end

      if defined?(Rails)
        Rails.application.config.after_initialize do
          ActiveRecord::Base.connection_pool.disconnect!

          ActiveSupport.on_load(:active_record) do
            config = Rails.application.config.database_configuration[Rails.env]
            config['pool'] = ENV['HEARST_LISTENER_CONCURRENCY'].to_i || 1
            ActiveRecord::Base.establish_connection(config)

            # DB connection not available during slug compliation on Heroku
            Rails.logger.info("Connection Pool size for Hearst is now: #{config['pool']}")
          end
        end
      end

      (ENV['HEARST_LISTENER_CONCURRENCY'].to_i || 1).times do
        listener = Hearst::Listener.new
        listener.listen
      end
    }
  end
end
