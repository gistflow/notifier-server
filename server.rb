require 'eventmachine'
require 'em-hiredis'

$debug = ENV['TEST'] == 'yep'

class NotificationServer < EM::Connection
  @@relations = {}
  
  class << self
    def notify(token, message)
      if channels = @@relations[token]
        p [:channels, channels] if $debug
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
    
    p [:token, token] if $debug
    
    token.chomp!
    @channel = EM::Channel.new
    @channel.subscribe do |message|
      p [:message, message] if $debug
      send_data(message + "\n")
    end
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
  
  if $debug
    publisher = EM::Hiredis.connect
    EM.add_periodic_timer(2) do
      publisher.publish("notifications:123", "hello")
    end
  end
end
