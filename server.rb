require 'eventmachine'
require 'em-hiredis'

class NotificationServer < EM::Connection
  @@relations = {}
  
  class << self
    def notify(token, message)
      if channels = @@relations[token]
        channels.each { |c| c.push message }
      end
    end
    
    def link(token, channel)
      @@relations[token] ||= []
      @@relations[token] << channel
    end
    
    def unlink(token, channel)
      @@relations[token].delete(channel)
      @@relations[token].empty? && @@relations.delete(token)
    end
  end
  
  def receive_data(token)
    return if @token # Antihack
    
    token.chomp!
    @channel = EM::Channel.new
    @channel.subscribe { |message| send_data(message) }
    self.class.link(token, @channel)
    @token = token
  end
  
  def unbind
    self.class.unlink(@token, @channel)
  end
end

EventMachine.run do
  Signal.trap("INT")  { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }

  redis = EM::Hiredis.connect
  redis.psubscribe('notifications:*')
  redis.on(:pmessage) do |key, channel, message|
    token = channel[/notifications:(.*)/, 1]
    NotificationServer.notify(token, message)
  end
  
  EventMachine.start_server('0.0.0.0', 1666, NotificationServer)
  
  # publisher = EM::Hiredis.connect
  # EM.add_periodic_timer(2) do
  #   publisher.publish("notifications:123", "hello")
  # end
end
