# frozen_string_literal: true
require 'httparty'
require 'json'
require 'uri'

module OpenAI
  class Client
    def initialize(data = {})
      base_url = data[:base_url]
      token = data[:token]
      @token = token.nil? ? "no_api_needed" : token
      @base_url = base_url.nil? ? "https://api.voids.top/v1/" : base_url
      @model = ""
      @system_prompt = ""
      @log = []

      puts "[Log] Endpoint: #{@base_url}"
      puts "[Log] Token: #{@token}"
    end

    def get_models
      begin
        endpoint = @base_url + "models"
        response = HTTParty.get(endpoint, timeout: 30)

        if response.code >= 400
          puts "[Error] Failed to get models, status code: #{response.code}"
          return nil
        end

        JSON.parse(response.body)
      rescue HTTParty::Error => e
        puts "[Error] HTTP request failed for get_models: #{e.message}"
        nil
      rescue JSON::ParserError => e
        puts "[Error] Failed to parse JSON response for get_models: #{e.message}"
        nil
      rescue StandardError => e
        puts "[Error] Unexpected error in get_models: #{e.message}"
        nil
      end
    end

    def get_message_log
      @log
    end

    def set_model!(model_id)
      @model = model_id
    end

    def set_system_prompt!(file)
      File.open(file, "r") do |f|
        f.each_line do |line|
          @system_prompt += line
        end
      end
    end

    def set_talk_log!(log)
      @log = log
    end

    def insert_system_prompt!
      log = [{
        "role" => "system",
        "content" => @system_prompt
      }]

      log.concat(@log)
      @log = log
    end

    def ask(retry_count = 3)
      begin
        endpoint = @base_url + "chat"
        body = {
          "model" => @model,
          "messages" => @log
        }
        headers = {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{@token}"
        }
        response = HTTParty.post(endpoint, body: JSON.generate(body), headers: headers, timeout: 120)
        puts response.code
        puts response.body

        if response.code >= 400
          puts "[Error] AI API returned error code: #{response.code}"
          if retry_count > 0
            puts "[Log] Retrying... (#{retry_count} attempts left)"
            sleep(2)
            return ask(retry_count - 1)
          else
            return nil
          end
        end

        JSON.parse(response.body)
      rescue HTTParty::Error => e
        puts "[Error] HTTP request failed for ask: #{e.message}"
        if retry_count > 0
          puts "[Log] Retrying... (#{retry_count} attempts left)"
          sleep(2)
          return ask(retry_count - 1)
        else
          nil
        end
      rescue JSON::ParserError => e
        puts "[Error] Failed to parse JSON response for ask: #{e.message}"
        nil
      rescue StandardError => e
        puts "[Error] Unexpected error in ask: #{e.message}"
        puts e.backtrace.first(3).join("\n")
        if retry_count > 0
          puts "[Log] Retrying... (#{retry_count} attempts left)"
          sleep(2)
          return ask(retry_count - 1)
        else
          nil
        end
      end
    end
  end
end
