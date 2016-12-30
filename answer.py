import socket
import sys

# connect to server
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect("SOCKPATH")

# get answer from command line argument
answer = ""
if len(sys.argv) > 1:
  answer = sys.argv[1] 

# send answer to server
print "trying: " + answer
sock.sendall(answer + "\n")

# get response
print "waiting for response:"
response = sock.recv(32)
print "got: " + response

# close connection to server 
sock.close
