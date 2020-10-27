require 'net/http'
require 'json'

class ApiCrawler
  class Error < ::StandardError ; end
  class MalformedResponseError < Error ; end

  attr_reader :num_pages, :pageno, :start_page, :stop_page, :total_pages, :url

  def initialize(options={})
    @benchmark_output = options[:benchmark_output]
    @output = options[:output]
    @num_pages = options[:num_pages] || Float::INFINITY
    @num_pages_processed = 0
    @start_page = options[:start_page]
    @stop_page = options[:stop_page] || Float::INFINITY
    @url = options[:url] || raise(ArgumentError, "Must supply :url")
    @url = "http://#{@url}" unless @url =~ /^https?:\/\//
    @pageno = options[:start_page] || 0
    @http_timeout = options[:http_timeout] || 3600
  end

  def crawl(options={})
    @start_page = options[:start_page] if options[:start_page]
    @stop_page = options[:stop_page] if options[:stop_page]

    next_uri = URI.parse(@url)

    next_uri.query = query_params_with_page(next_uri.query, @start_page)

    while next_uri do
      benchmark(next_uri) do
        http = Net::HTTP.new(next_uri.host, next_uri.port)
        http.open_timeout = @http_timeout
        http.read_timeout = @http_timeout
        response = http.start do |http|
          path = if next_uri.query
            next_uri.path.to_s + "?" + next_uri.query
          else
            next_uri.path.to_s
          end
          path = "/" if path.blank?
          http.get path
        end
        next_uri = process_response_body_and_get_next_page_uri(next_uri, response.body)
      end
    end
  end

  def pages_left?
    return true unless @total_pages
    pages_left_to_crawl? && not_at_the_stop_page?
  end

  private

  def benchmark(uri, &blk)
    if @benchmark_output
      n = Time.now
      yield
      duration = Time.now - n
      @benchmark_output.puts "#{uri} took #{duration} seconds"
    else
      yield
    end
  end

  def process_response_body_and_get_next_page_uri(request_uri, response_body)
    begin
      json_data = JSON.parse(response_body)
    rescue JSON::ParserError
      raise(MalformedResponseError, "Response body was not valid JSON in:\n #{response_body}")
    end

    @output.puts response_body.gsub("\n", "")
    @num_pages_processed += 1

    meta = json_data["meta"]
    if meta && meta["page"] && meta["total_pages"]
      @pageno = meta["page"]
      @total_pages = meta["total_pages"]
    else
      # if we have a page of valid JSON w/o paging information
      @total_pages ||= 1
      @pageno = @total_pages
    end

    if continue_crawling?
      next_uri = URI.parse(@url)
      next_uri.query = query_params_with_page(next_uri.query, @pageno+1)
      next_uri
    else
      nil
    end
  end

  def query_params_with_page(query, page)
    return query unless page
    params = Rack::Utils.parse_nested_query(query).with_indifferent_access
    params[:page] = page
    params.to_query
  end

  def continue_crawling?
    pages_left_to_crawl? &&
      not_at_the_stop_page? &&
      not_at_the_num_pages_threshold?
  end

  def pages_left_to_crawl?
    @pageno < @total_pages
  end

  def not_at_the_stop_page?
    @pageno < @stop_page
  end

  def not_at_the_num_pages_threshold?
    @num_pages_processed < @num_pages
  end
end
