require 'eventmachine'
require 'em-hiredis'

class NotificationServer < EM::Connection
  @@relations = {}
  
  def self.notify(token, message)
    channel = @@relations[token]
    channel.push message if channel
  end
  
  def receive_data(token)
    token.chomp!
    p [:receive_data, token]
    channel = EM::Channel.new
    @@relations[token] = channel
    channel.subscribe do |message|
      p [:subscribe, message]
      send_data(message)
    end
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
