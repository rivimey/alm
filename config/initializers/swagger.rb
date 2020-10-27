Swagger::Docs::Config.register_apis(
  "v7" => {
    api_file_path: "public",
    base_api_controller: "Api::BaseController",
    base_path: ENV['SERVER_URL'],
    :attributes => {
      :info => {
        "title" => "API",
        "description" => "This is the live documentation of the Lagotto API. The current API is v7, please use <a href='http://#{ENV['SERVERNAME']}/api/'>http://#{ENV['SERVERNAME']}/api/</a> as base URL. Go to <a href='/docs/api'>API Docs</a> for more detailed documentation, or to <a href='http://discuss.lagotto.io'>http://discuss.lagotto.io</a> for questions or comments regarding the Lagotto API." }
    }
  }
)
