Alm::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => "users/omniauth_callbacks", :registrations => "users/registrations" }

  root :to => "docs#show"

  # constraints is added to allow dot in the url (doi is used to show article)
  resources :articles, :constraints => { :id => /.+?/, :format => /html/}

  resources :sources
  resources :users
  resources :docs, :only => :show, :constraints => { :id => /[0-z\-\.\(\)]+/ }

  match "oembed" => "oembed#show"

  namespace :admin do
    root :to => "index#index"
    resources :articles, :constraints => { :id => /.+?/, :format => /html|js/ }
    resources :sources
    resources :groups
    resources :delayed_jobs
    resources :errors
    resources :events
    resources :responses
    resources :alerts
    resources :api_requests
    resources :users
    resources :filters
  end

  namespace :api do
    namespace :v3 do
      root :to => "articles#index"
      resources :articles, :constraints => { :id => /.+?/, :format=> false }, only: [:index, :show]
    end

    namespace :v4 do
      root :to => "articles#index"
      resources :articles, :constraints => { :id => /.+?/, :format=> false }
    end
  end
end
