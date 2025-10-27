# frozen_string_literal: true
require 'dotenv/load'
require 'httparty'
require 'nokogiri'
require 'json'
require 'date'
require './data/genre'
require './lib/openai'
require './lib/narou'

API_KEY = ENV["COHERE_API_KEY"]
API_ENDPOINT = ENV['COHERE_API_ENDPOINT']
DISCORD_WEBHOOK_URL = ENV['DISCORD_WEBHOOK_URL']


AIClient = OpenAI::Client.new(:base_url => API_ENDPOINT, :token => API_KEY)
NarouApiClient = Narou::ApiClient.new
NarouAppClient = Narou::AppClient.new

def novel_ranking
  ranking_res = NarouApiClient.get_ranking("weekly", "re", 20)
  ranking_data = Array.new

  ranking_res.each_with_index do |novel, index|
    next if index == 0

    puts novel
    novel_id = novel["ncode"].downcase
    puts "[Log] Novel ID: #{novel_id}"
    novel_text = NarouAppClient.get_novel_text(novel_id, 1)
    html = Nokogiri::HTML5(novel_text)
    content = html.css(".js-novel-text.p-novel__text").text
    ranking_data << {
      "title" => novel["title"],
      "description" => novel["story"],
      "tags" => novel["keyword"].split(" "),
      "genre" => Genres[novel["genre"]],
      "first_episode" => content[0..500]
    }

    sleep(0.5)
  end

  ranking_data
end

def main
  model_id = "command-a-03-2025"

  if model_id == ""
    puts "No models found"
    return
  end

  puts "[Log] model_id: #{model_id}"
  AIClient.set_model!(model_id)
  AIClient.set_system_prompt!("./data/system.txt")

  puts "[Log] Fetching novel ranking data..."
  ranking_data = novel_ranking
  puts "[Log] Fetched #{ranking_data.length} novels."

  ranking_messages = []
  ranking_data.each do |data|
    # API expects messages to be objects with role and content
    ranking_messages << {
      "role" => "user",
      # send a Hash (object) instead of a JSON string so the model can extract fields
      "content" => JSON.generate(data)
    }
  end

  AIClient.set_talk_log!(ranking_messages)
  # システムプロンプトを先頭に挿入
  AIClient.insert_system_prompt!

  response = AIClient.ask
  status = response["finish_reason"]
  unless status == "COMPLETE"
    puts "[Error] AI response incomplete: #{status}"
    return
  end
  content = response["message"]["content"][0]["text"]
  contents = content.scan(/.{1,2000}/m)
  w_responses = []

  contents.each do |part|
    puts "[Log] Sending to Discord..."
    puts part
    body = {
      "content" => part
    }
    w_response = HTTParty.post(DISCORD_WEBHOOK_URL, body: JSON.generate(body), headers: { "Content-Type" => "application/json" })
    puts "[Log] Discord response code: #{w_response.code}"
    w_responses << w_response
    sleep(1)
  end
  File.open("./response/ai.json", "w") do |file|
    file.write JSON.pretty_generate(AIClient.ask)
  end
  File.open("./response/discord_responses.json", "w") do |file|
    file.write JSON.pretty_generate(w_responses)
  end
end

def ai_test
  AIClient.set_model!("command-a-03-2025")

  messages = [
    {
      "role" => "user",
      "content" => "以下の文章を要約してください。\n\n今日はとても良い天気です。散歩に出かけるには最適な日です。公園では子供たちが遊んでおり、家族連れも楽しんでいます。"
    }
  ]

  AIClient.set_talk_log!(messages)
  response = AIClient.ask
  puts JSON.pretty_generate(response)
end


main