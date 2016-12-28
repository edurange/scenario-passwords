require 'socket'

socket = UNIXSocket.new("SOCKPATH")
answer = ARGV[0] 
puts "trying: #{answer}\n"
socket.puts answer
puts socket.gets
socket.close
