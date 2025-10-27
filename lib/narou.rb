# frozen_string_literal: true
require 'httparty'
require 'json'
require 'uri'


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
      endpoint = @base_url + "novelapi/api/?out=json&ncode=#{ncode}"

      response = HTTParty.get(endpoint, headers: @headers)
      JSON.parse(response.body)
    end

    def get_ranking(ranking_type, novel_type = "re", size = 10)
      endpoint = @base_url + "novelapi/api/?out=json&lim=#{size}&order=#{ranking_type}points&type=#{novel_type}"
      puts endpoint

      response = HTTParty.get(endpoint, headers: @headers)
      JSON.parse(response.body)
    end
  end

  class AppClient
    def initialize
      @user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
      @headers = {
        'User-Agent' => @user_agent,
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
      }
    end

    def get_novel_text(ncode, index = 1)
      endpoint = "https://ncode.syosetu.com/#{ncode}/#{index}"
      puts endpoint
      response = HTTParty.get(endpoint, headers: @headers)
      response.body
    end
  end
end
