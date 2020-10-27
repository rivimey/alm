require 'faraday'
require 'faraday_middleware'
require 'net/http'
require 'excon'
require 'uri'

module Networkable
  extend ActiveSupport::Concern

  included do
    def get_result(url, options={})
      options[:headers] = set_request_headers(url, options)

      conn = faraday_conn(options)

      conn.options[:timeout] = options[:timeout] || DEFAULT_TIMEOUT

      if options[:data]
        response = conn.post url, {}, options[:headers] do |request|
          request.body = options[:data]
        end
      else
        response = conn.get url, {}, options[:headers]
      end
      # set number of available API calls for agents
      if options[:agent_id].present?
        agent = Agent.where(id: options[:agent_id]).first
        agent.update_attributes(rate_limit_remaining: get_rate_limit_remaining(response.headers),
                                rate_limit_reset: get_rate_limit_reset(response.headers),
                                last_response: Time.zone.now)
      end
      # parsing by content type is not reliable, so we check the response format
      parse_success_response(response.body)
    rescue *NETWORKABLE_EXCEPTIONS => e
      rescue_faraday_error(url, e, options)
    end

    def set_request_headers(url, options)
      options[:headers] ||= {}
      options[:headers]['Host'] = URI.parse(url).host

      if options[:content_type].present?
        accept_headers = { "html" => 'text/html; charset=UTF-8',
                           "xml" => 'application/xml',
                           "json" => 'application/json' }
        options[:headers]['Accept'] = accept_headers.fetch(options[:content_type], options[:content_type])
      else
        options[:headers]['Accept'] ||= "application/json"
      end

      if options[:bearer].present?
        options[:headers]['Authorization'] = "Bearer #{options[:bearer]}"
      elsif options[:token].present?
        options[:headers]["Authorization"] = "Token token=#{options[:token]}"
      elsif options[:username].present?
        options[:headers]["Authorization"] = ActionController::HttpAuthentication::Basic.encode_credentials(options[:username], options[:password])
      end

      options[:headers]
    end

    def faraday_conn(options = {})
      options[:limit] ||= 10

      Faraday.new do |c|
        c.headers['Accept'] = options[:headers]['Accept']
        c.headers['User-Agent'] = "Lagotto - http://#{ENV['SERVERNAME']}"
        c.use      FaradayMiddleware::FollowRedirects, limit: options[:limit]
        c.use      :cookie_jar
        c.request  :multipart
        c.request  :json if options[:headers]['Accept'] == 'application/json'
        c.use      Faraday::Response::RaiseError
        c.adapter  Faraday.default_adapter
      end
    end

    def rescue_faraday_error(url, error, options={})
      if error.is_a?(Faraday::ResourceNotFound)
        not_found_error(url, error, options)
      else
        details = nil
        headers = {}

        if error.is_a?(Faraday::Error::TimeoutError)
          status = 408
        elsif error.respond_to?('status')
          status = error[:status]
        elsif error.respond_to?('response') && error.response.present?
          status = error.response[:status]
          details = error.response[:body]
          headers = error.response[:headers]
        else
          status = 400
        end

        # Some sources use a different status for rate-limiting errors
        status = 429 if status == 403 && details.include?("Excessive use detected")

        if error.respond_to?('exception')
          exception = error.exception
        else
          exception = ""
        end

        class_name = class_name_by_status(status) || error.class
        level = level_by_status(status)

        message = parse_error_response(error.message)
        message = "#{message} for #{url}"
        message = "#{message}. Rate-limit #{get_rate_limit_limit(headers)} exceeded." if class_name == Net::HTTPTooManyRequests

        Notification.where(message: message).where(unresolved: true).first_or_create(
          exception: exception,
          class_name: class_name.to_s,
          details: details,
          status: status,
          target_url: url,
          level: level,
          work_id: options[:work_id],
          source_id: options[:source_id])

        { error: message, status: status }
      end
    end

    def not_found_error(url, error, options={})
      status = 404
      # we raise an error if we find a canonical URL mismatch
      # or a DOI can't be resolved
      if options[:doi_mismatch] || options[:doi_lookup]
        work = Work.where(id: options[:work_id]).first
        if options[:doi_mismatch]
          message = error.response[:message]
        else
          message = "DOI #{work.doi} could not be resolved"
        end
        Notification.where(message: message).where(unresolved: true).first_or_create(
          exception: error.exception,
          class_name: "Net::HTTPNotFound",
          details: error.response[:body],
          status: status,
          work_id: work.id,
          target_url: url)
        { error: message, status: status }
      else
        if error.response.blank? && error.response[:body].blank?
          message = "resource not found"
        else
          message = parse_error_response(error.response[:body])
        end
        { error: message, status: status }
      end
    end

    def class_name_by_status(status)
      { 400 => Net::HTTPBadRequest,
        401 => Net::HTTPUnauthorized,
        403 => Net::HTTPForbidden,
        404 => Net::HTTPNotFound,
        406 => Net::HTTPNotAcceptable,
        408 => Net::HTTPRequestTimeOut,
        409 => Net::HTTPConflict,
        417 => Net::HTTPExpectationFailed,
        429 => Net::HTTPTooManyRequests,
        500 => Net::HTTPInternalServerError,
        502 => Net::HTTPBadGateway,
        503 => Net::HTTPServiceUnavailable,
        504 => Net::HTTPGatewayTimeOut }.fetch(status, nil)
    end

    def level_by_status(status)
      case status
      # temporary network problems should be WARN not ERROR
      when 408, 502, 503, 504 then 2
      else 3
      end
    end

    # currently supported by twitter, github, ads and ads_fulltext
    # agents with slightly different header names
    def get_rate_limit_remaining(headers)
      headers["X-Rate-Limit-Remaining"] || headers["X-RateLimit-Remaining"]
    end

    def get_rate_limit_limit(headers)
      headers["X-Rate-Limit-Limit"] || headers["X-RateLimit-Limit"]
    end

    def get_rate_limit_reset(headers)
      headers["X-Rate-Limit-Reset"] || headers["X-RateLimit-Reset"]
    end

    def parse_success_response(string)
      string = parse_response(string)

      # if string == ""
      #   { 'data' => nil }
      # elsif string.is_a?(Hash) && string['data']
      #   string
      # elsif string.is_a?(Hash) && string['hash']
      #   { 'data' => string['hash'] }
      # else
      #   { 'data' => string }
      # end
    end

    def parse_error_response(string)
      string = parse_response(string)

      if string.is_a?(Hash) && string['error']
        string['error']
      else
        string
      end
    end

    protected

    def parse_response(string)
      parse_from_json(string) || parse_from_xml(string) || parse_from_string(string)
    end

    def parse_from_xml(string)
      if Nokogiri::XML(string).errors.empty?
        Hash.from_xml(string)
      else
        nil
      end
    end

    def parse_from_json(string)
      JSON.parse(string)
    rescue JSON::ParserError
      nil
    end

    def parse_from_string(string)
      string.gsub(/\s+\n/, "\n").strip.force_encoding('UTF-8')
    end
  end
end
