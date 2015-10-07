require 'slack-ruby-client'
require 'mechanize'
require 'uri'

mechanize = Mechanize.new

def get_kindred_cocktail(url)
  page = mechanize.get(URI(url))

  cocktail_name = page.at('#page-title').text.strip
  recipe = page.at('div.node-content table').text.lines.map{|line| line.strip}.join("\n")

  puts cocktail_name + recipe

  return cocktail_name + recipe
end

def get_named_cocktail(name)
  url = 'http://www.kindredcocktails.com/cocktail/' + name.strip.downcase.gsub(' ', '-')
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
  case data['text']
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
  when /what'*s in a (.+)/ then
    if (cocktail_name = data['text'].match(/what'*s in a ([^\?]+)\?/))
      get_named_cocktail(cocktail_name)
    end
  end
end

client.start!
