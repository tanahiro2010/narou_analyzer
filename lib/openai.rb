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
      endpoint = @base_url + "models"
      response = HTTParty.get(endpoint)
      JSON.parse(response.body)
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

    def ask
      endpoint = @base_url + "chat"
      body = {
        "model" => @model,
        "messages" => @log
      }
      headers = {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@token}"
      }
      response = HTTParty.post(endpoint, body: JSON.generate(body), headers: headers)
      puts response.code
      puts response.body
      JSON.parse(response.body)
    end
  end
end
