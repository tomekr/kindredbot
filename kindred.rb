require 'slack-ruby-client'
require 'mechanize'
require 'uri'

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
        if (cocktail_name = data['text'].downcase.match(/what.?s in an? ([^\?]+)\?/)[1])
          recipe = get_named_cocktail(cocktail_name)
          client.message channel: data['channel'], text: recipe
        end
      rescue Exception => e
        puts "A parsing error occured 8/"
        puts e.inspect
      end
    end
  end
end

client.start!
