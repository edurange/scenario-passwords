require 'socket'

socket = UNIXSocket.new("/var/run/edurange/passwords/answer.sock")
answer = "foo:bar\n"
puts "trying: #{answer}"
socket.write answer
puts socket.gets

socket.close
