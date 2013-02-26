STREAMING_URL = 'https://stream.twitter.com/1.1/statuses/filter.json'#'https://stream.twitter.com/1/statuses/sample.json'
TWITTER_USERNAME = ENV['TWITTER_USERNAME']
TWITTER_PASSWORD = ENV['TWITTER_PASSWORD']

configure do
  if ENV['MONGOHQ_URL']
    uri = URI.parse(ENV['MONGOHQ_URL'])
    conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
    DB = conn.db(uri.path.gsub(/^\//, ''))
  else
    DB = Mongo::Connection.new.db("mongo-twitter-streaming")
  end
  
  DB.create_collection("tweets", :capped => true, :size => 10485760)
end

get '/' do
  content_type 'text/html', :charset => 'utf-8'
  @tweets = DB['tweets'].find({}, :limit => 10, :sort => [[ '$natural', :desc ]])
  erb :index
end

EM.schedule do
  http = EM::HttpRequest.new(STREAMING_URL).post :head => { 'Authorization' => [ TWITTER_USERNAME, TWITTER_PASSWORD ] }
  buffer = "track=twitter" #{}""
  http.stream do |chunk|
    buffer += chunk
    while line = buffer.slice!(/.+\r?\n/)
      tweet = JSON.parse(line)
      DB['tweets'].insert(tweet) if tweet['text']
    end
  end
end
