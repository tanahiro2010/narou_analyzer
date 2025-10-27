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

# Safari User-Agent (latest version)
SAFARI_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

# 短編(t)か長編(re)か、デフォルトは長編
NOVEL_TYPE = ENV['NOVEL_TYPE'] || "re"  # "t" for 短編, "re" for 長編(連載中)
RANKING_SIZE = (ENV['RANKING_SIZE'] || "20").to_i

AIClient = OpenAI::Client.new(:base_url => API_ENDPOINT, :token => API_KEY)
NarouApiClient = Narou::ApiClient.new
NarouAppClient = Narou::AppClient.new(:user_agent => SAFARI_USER_AGENT)

def novel_ranking(novel_type = NOVEL_TYPE, size = RANKING_SIZE)
  begin
    puts "[Log] Fetching ranking for type: #{novel_type}, size: #{size}"
    ranking_res = NarouApiClient.get_ranking("weekly", novel_type, size)

    if ranking_res.nil? || ranking_res.empty?
      puts "[Error] No ranking data received"
      return []
    end

    ranking_data = Array.new

    ranking_res.each_with_index do |novel, index|
      next if index == 0

      begin
        puts novel
        novel_id = novel["ncode"]&.downcase

        unless novel_id
          puts "[Warning] Novel without ncode, skipping..."
          next
        end

        puts "[Log] Novel ID: #{novel_id}"
        novel_text = NarouAppClient.get_novel_text(novel_id, 1)

        if novel_text.nil? || novel_text.empty?
          puts "[Warning] Failed to fetch novel text for #{novel_id}, skipping..."
          next
        end

        html = Nokogiri::HTML5(novel_text)
        content = html.css(".js-novel-text.p-novel__text").text

        if content.empty?
          puts "[Warning] No content found for #{novel_id}, using description only"
          content = novel["story"] || ""
        end

        ranking_data << {
          "title" => novel["title"] || "タイトルなし",
          "description" => novel["story"] || "",
          "tags" => (novel["keyword"] || "").split(" "),
          "genre" => Genres[novel["genre"]] || "不明",
          "first_episode" => content[0..500]
        }

        sleep(0.5)
      rescue StandardError => e
        puts "[Error] Failed to process novel #{novel_id rescue 'unknown'}: #{e.message}"
        puts e.backtrace.first(3).join("\n")
        next
      end
    end

    ranking_data
  rescue StandardError => e
    puts "[Error] Failed to fetch ranking: #{e.message}"
    puts e.backtrace.first(3).join("\n")
    return []
  end
end

def main
  begin
    model_id = "command-a-03-2025"

    if model_id == ""
      puts "No models found"
      return
    end

    puts "[Log] model_id: #{model_id}"
    AIClient.set_model!(model_id)

    begin
      AIClient.set_system_prompt!("./data/system.txt")
    rescue StandardError => e
      puts "[Warning] Failed to load system prompt: #{e.message}"
      puts "[Warning] Continuing without system prompt..."
    end

    puts "[Log] Fetching novel ranking data..."
    ranking_data = novel_ranking
    puts "[Log] Fetched #{ranking_data.length} novels."

    if ranking_data.empty?
      puts "[Error] No ranking data available. Exiting..."
      return
    end

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

    begin
      response = AIClient.ask

      if response.nil?
        puts "[Error] AI response is nil"
        return
      end

      status = response["finish_reason"]
      unless status == "COMPLETE"
        puts "[Error] AI response incomplete: #{status}"
        puts "[Warning] Attempting to use partial response..."
      end

      content = response.dig("message", "content", 0, "text")

      unless content
        puts "[Error] No content in AI response"
        return
      end

      contents = content.scan(/.{1,2000}/m)
      w_responses = []

      contents.each do |part|
        begin
          puts "[Log] Sending to Discord..."
          puts part
          body = {
            "content" => part
          }
          w_response = HTTParty.post(DISCORD_WEBHOOK_URL, body: JSON.generate(body), headers: { "Content-Type" => "application/json" })
          puts "[Log] Discord response code: #{w_response.code}"

          if w_response.code >= 400
            puts "[Warning] Discord returned error code: #{w_response.code}"
            puts "[Warning] Response: #{w_response.body}"
          end

          w_responses << w_response
          sleep(1)
        rescue StandardError => e
          puts "[Error] Failed to send to Discord: #{e.message}"
          puts e.backtrace.first(3).join("\n")
          next
        end
      end

      # Save responses to file
      begin
        File.open("./response/ai.json", "w") do |file|
          file.write JSON.pretty_generate(response)
        end
        puts "[Log] Saved AI response to ./response/ai.json"
      rescue StandardError => e
        puts "[Error] Failed to save ai.json: #{e.message}"
      end

      begin
        File.open("./response/discord_responses.json", "w") do |file|
          file.write JSON.pretty_generate(w_responses)
        end
        puts "[Log] Saved Discord responses to ./response/discord_responses.json"
      rescue StandardError => e
        puts "[Error] Failed to save discord_responses.json: #{e.message}"
      end

    rescue StandardError => e
      puts "[Error] AI API request failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      return
    end

  rescue StandardError => e
    puts "[Fatal Error] Unexpected error in main: #{e.message}"
    puts e.backtrace.first(5).join("\n")
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