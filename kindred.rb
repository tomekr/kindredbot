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
  end
end

client.start!
