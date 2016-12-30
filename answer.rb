require 'socket'

# connect to unix socket
socket = UNIXSocket.new("SOCKPATH")

# get answer from command line
answer = ARGV[0] 

puts "trying: #{answer}\n"

# send answer
socket.puts answer

# receive answer
response = socket.gets
print response

socket.close
