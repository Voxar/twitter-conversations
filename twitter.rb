require 'rubygems'
require 'open-uri'
require 'JSON'
require 'pp'

args = $*

username = nil
password = nil
do_status = nil #set to status id if you want to follow a specific conversation
do_user = nil   #to get conversations that a specific user is in

if args.length == 2
  username, password = args
elsif args.length == 1
  if args.first =~ /\d+/
    do_status = args.first 
  else
    do_user = args.first
  end
else
  puts "Usage: ruby #{File.basename(__FILE__)} username password"
  puts "  to follow conversations your friends are in"
  puts "  example: ruby twitter.rb <secret> <secret>"
  puts "OR: ruby #{File.basename(__FILE__)} status_id"
  puts "  to follow specific conversation (from status_id and up)"
  puts "  example: ruby twitter.rb 1564420484"
  puts "OR: ruby #{File.basename(__FILE__)} username"
  puts "  to follow conversations that user is in"
  puts "  example: ruby twitter.rb voxar"
  exit
end

DEBUG = false
AUTH = {:http_basic_authentication=>[username, password]}

def check_if_old(filename)
  if Time.new.to_f - File.mtime(filename).to_f > 60*5
    File.delete(filename)
  end
end

def cache(url, use_auth)
  Dir.mkdir("cache") if not File.exists?('cache')
  filename = "cache/#{url.hash.to_s}"
#  check_if_old(filename) if File.exist?(filename) #no need. statuses rarely change and timeline skips cache...
  if File.exist?(filename)
    Marshal.load(open(filename).read)
  else
    data = _get(url, use_auth)
    open(filename, "w"){ |f| f.write(Marshal.dump(data)) }
    data
  end
end

def get(url, use_auth=false)
  cache(url, use_auth)
end

def _get(url, use_auth=false)
  auth = use_auth ? AUTH : nil
  begin
    JSON.parse(open(url, AUTH).read)
#  rescue OpenURI::HTTPError=>err
  end
end

def get_status(id)
  get("http://twitter.com/statuses/show.json?id=#{id}")
end

def get_thread(post)
  thread = [post]
  while reply_id = post["in_reply_to_status_id"]
    post = get_status(reply_id)
    thread << post
  end
  thread.reverse
end

if do_status
  data = [get_status(do_status)]
elsif do_user
  data = _get("http://twitter.com/statuses/user_timeline.json?screen_name=#{do_user}")
else
  #always want new version of timeline, so skip cache
  data = _get("http://twitter.com/statuses/friends_timeline.json", true)
end
#map posts as threads
threads = data.map { |post| get_thread(post) }
#sort out thread copies
threadmap = {}#map threads by root id
threads.each do |thread|
  id = thread.first['id'] #get id of root post
  t = threadmap[id]
  if not t or thread.length > t.length
    puts "THREAD REPLACED"*100 if t
    threadmap[id] = thread
  end
end

def sorter a,b
  Date.parse(a.first['created_at']) <=> Date.parse(b.first['created_at'])
end

threadmap.values.sort{ |a,b| sorter(a,b) }.each do |thread|
  thread.each do |post|
    puts "#{post['user']['name']} (#{post['user']['screen_name']}) says: #{post['text']}"
    puts "id #{post['id']}#{" reply to #{post['in_reply_to_status_id']}" if post['in_reply_to_status_id']} at #{post['created_at']}\n" if DEBUG
  end
  puts
end

if DEBUG
  puts "*"*50
  pp data.first
end
