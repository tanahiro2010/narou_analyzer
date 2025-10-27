# frozen_string_literal: true
require 'httparty'
require 'json'
require 'uri'
a

module Narou
  class ApiClient
    def initialize(data = {})
      base_url = data[:base_url]
      @base_url = base_url.nil? ? "https://api.syosetu.com/" : base_url
      @user_agent = "ApiClient/1.0 (+Narou Ruby Client) - Narou analyzer"

      @headers = {
        'User-Agent' => @user_agent,
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
      }
    end

    def get_novel(ncode)
      begin
        endpoint = @base_url + "novelapi/api/?out=json&ncode=#{ncode}"

        response = HTTParty.get(endpoint, headers: @headers, timeout: 30)

        if response.code >= 400
          puts "[Error] API returned error code: #{response.code}"
          return nil
        end

        JSON.parse(response.body)
      rescue HTTParty::Error => e
        puts "[Error] HTTP request failed for get_novel: #{e.message}"
        nil
      rescue JSON::ParserError => e
        puts "[Error] Failed to parse JSON response for get_novel: #{e.message}"
        nil
      rescue StandardError => e
        puts "[Error] Unexpected error in get_novel: #{e.message}"
        nil
      end
    end

    def get_ranking(ranking_type, novel_type = "re", size = 10)
      begin
        endpoint = @base_url + "novelapi/api/?out=json&lim=#{size}&order=#{ranking_type}points&type=#{novel_type}"
        puts endpoint

        response = HTTParty.get(endpoint, headers: @headers, timeout: 30)

        if response.code >= 400
          puts "[Error] API returned error code: #{response.code}"
          return []
        end

        JSON.parse(response.body)
      rescue HTTParty::Error => e
        puts "[Error] HTTP request failed for get_ranking: #{e.message}"
        []
      rescue JSON::ParserError => e
        puts "[Error] Failed to parse JSON response for get_ranking: #{e.message}"
        []
      rescue StandardError => e
        puts "[Error] Unexpected error in get_ranking: #{e.message}"
        []
      end
    end
  end

  class AppClient
    def initialize(data = {})
      user_agent = data[:user_agent]
      # Default to Safari User-Agent if not specified
      @user_agent = user_agent.nil? ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15" : user_agent
      @headers = {
        'User-Agent' => @user_agent,
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
      }
    end

    def get_novel_text(ncode, index = 1)
      begin
        endpoint = "https://ncode.syosetu.com/#{ncode}/#{index}"
        puts endpoint
        response = HTTParty.get(endpoint, headers: @headers, timeout: 30)

        if response.code >= 400
          puts "[Error] Failed to fetch novel text, status code: #{response.code}"
          return nil
        end

        response.body
      rescue HTTParty::Error => e
        puts "[Error] HTTP request failed for get_novel_text: #{e.message}"
        nil
      rescue StandardError => e
        puts "[Error] Unexpected error in get_novel_text: #{e.message}"
        nil
      end
    end
  end
end
