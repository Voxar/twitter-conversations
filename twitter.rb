require 'rubygems'
require 'open-uri'
require 'JSON'
require 'pp'

args = $*

username = nil
password = nil

unless args.length >= 2
  puts "Usage: #{File.basename(__FILE__)} username password"
  exit
end

username, password = args

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

def format(post)
  "#{post["user"]["name"]}\n  #{post["text"]}"
end

#always want new version of timeline, so skip cache
data = _get("http://twitter.com/statuses/friends_timeline.json", true)

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
