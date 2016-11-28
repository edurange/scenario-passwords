require 'socket'

socket = UNIXSocket.new("socket")

1.times do |n|
  answer = "Takako:brighton\n"
  puts "try:#{answer}"
  socket.write(answer)
  puts socket.gets
end

socket.close
