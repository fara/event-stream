logger = Logger.new(STDOUT)
logger.level = Logger::WARN

#STREAMING_URL = 'https://stream.twitter.com/1/statuses/sample.json'
STREAMING_URL = 'https://stream.twitter.com/1.1/statuses/filter.json'
TWITTER_USERNAME = ENV['TWITTER_USERNAME']
TWITTER_PASSWORD = ENV['TWITTER_PASSWORD']
TRACK_WORD = "#claudioubeda"

configure do
  if ENV['MONGOHQ_URL']
    uri = URI.parse(ENV['MONGOHQ_URL'])
    conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])    
    DB = conn.db(uri.path.gsub(/^\//, ''))
    DB.create_collection("tweets", :capped => true, :size => 10485760)
  else
    DB = Mongo::Connection.new.db("event-stream")
    DB.create_collection("tweets", :capped => true, :size => 1048576)
  end  
  
end

set :public_folder, 'public'

get '/' do
  content_type 'text/html', :charset => 'utf-8'
  erb :index
end

get '/search' do
  @tweets = DB['tweets'].find({}, :limit => 10, :sort => [[ 'id_str', :desc ]])
  content_type :json
  @tweets.to_a.to_json
end

EM.schedule do
  http = EM::HttpRequest.new(
    STREAMING_URL,
    :connection_timeout => 0,
    :inactivity_timeout => 0).post(
      :head => { 'Authorization' => [ TWITTER_USERNAME, TWITTER_PASSWORD ] }, 
      :body => {:track => TRACK_WORD})
   
  buffer = ""
  http.stream do |chunk|
    buffer += chunk
    while line = buffer.slice!(/.+\r?\n/)
      logger.info line
      begin
        tweet = JSON.parse(line)
        DB['tweets'].insert(tweet) if tweet['text']
      rescue JSON::ParserError => e
        logger.error line
      end
    end
  end
end
