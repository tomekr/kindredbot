require 'slack-ruby-client'
require 'mechanize'
require 'uri'

DRINKS = [ "Jager Bomb\n\n1/2 can Red Bull\n2 oz Jagermeister", 
           "Angry Balls\n\n2 oz Fireball Whisky\n1 pint Angry Orchard Apple Hard Cider", 
           "Irish Car Bomb\n\n3/4 pint Guinness\n1 oz Bailey's Irish Cream\n1 oz Jameson Irish whiskey",
           "Long Island Iced Tea\n\n1 oz Vodka\n1 oz Gin\n1 oz White Rum\n1 oz White Tequila\n1/2 oz Triple Sec\n2 tbsp Lemon Juice\n1/2 cup Cola",
           "Toilet Duck\n\n2 oz Vodka\n1 bottle Smirnoff Ice\n1 bottle WKD Blue"]

def get_kindred_cocktail(url)
  mechanize = Mechanize.new
  page = mechanize.get(URI(url))

  cocktail_name = page.at('#page-title').text.strip
  recipe = page.at('div.node-content table').text.lines.map{|line| line.strip}.join("\n")

  puts cocktail_name + recipe

  return cocktail_name + recipe
end

def get_named_cocktail(name)
  normalized_name = name.strip.downcase.gsub(' ', '-').delete('^a-zA-Z-0-9')

  puts "looking up recipe for #{normalized_name}"
  url = 'http://www.kindredcocktails.com/cocktail/' + normalized_name
  get_kindred_cocktail(url)
end

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
  fail 'Missing ENV[SLACK_API_TOKEN]!' unless config.token
end

client = Slack::RealTime::Client.new

client.on :hello do
  puts "Successfully connected, welcome '#{client.self['name']}' to the '#{client.team['name']}' team at https://#{client.team['domain']}.slack.com."
end

client.on :message do |data|
  # It may be possible that you get a message with no text
  if data['text']
    case data['text'].downcase
    when /http:\/\/www\.kindredcocktails\.com/ then
      begin
        if (url = data['text'].match(/<(http:\/\/www\.kindredcocktails\.com.+)>/)[1])
          recipe = get_kindred_cocktail(url)
          client.message channel: data['channel'], text: recipe
        end
      rescue Exception => e
        puts "A parsing error occured 8/"
        puts e.inspect
      end
    # .{0,1} is because of directional apostrophes. I didn't want it to be this
    # way but you forced my hand.
    when /what.?s in an? ([^\?]+)\?/ then
      puts "received what's in a request #{ data['text'] }"
      begin
        if data["user"] == "marcinw"
          client.message channel: data['channel'], text: DRINKS.sample
        elsif (cocktail_name = data['text'].downcase.match(/what.?s in an? ([^\?]+)\?/)[1])
          recipe = get_named_cocktail(cocktail_name)
          client.message channel: data['channel'], text: recipe
        end
      rescue Exception => e
        puts "A parsing error occured 8/"
        puts e.inspect

        cocktail_name = data['text'].downcase.match(/what.?s in an? ([^\?]+)\?/)[1]
        client.message channel: data['channel'], text: "Sorry, I couldnt find a cocktail with the name #{cocktail_name}"
      end
    end
  end
end

client.start!
