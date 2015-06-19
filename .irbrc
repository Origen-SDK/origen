$VERBOSE=nil
require 'pp'
require 'rubygems'

#require 'wirble'

#Wirble.init
#Wirble.colorize

IRB.conf[:AUTO_INDENT] = true

def ls
  %x{ls}.split("\n")
end
 
def cd(dir)
  Dir.chdir(dir)
  Dir.pwd
end
 
def pwd
  Dir.pwd
end
