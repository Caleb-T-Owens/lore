Rails.application.routes.draw do
  root "home#index"
  get "home", to: redirect("/")
  get "search", to: "search#index", as: :search
  get "getting-started.md", to: "getting_started#show", as: :getting_started

  namespace :api do
    resources :repos, only: :create
    resources :users, only: :create

    get "me", to: "users#me", as: :current_user
    get "repos/search", to: "repos#search", as: :search_repos
    get "repos/:owner/:name", to: "repos#show", as: :repo
    post "repos/:owner/:name/star", to: "repos#star", as: :star_repo
    delete "repos/:owner/:name/star", to: "repos#unstar"
    get "users/:username/repos", to: "users#repos", as: :user_repos
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get ":owner/:repo", to: "repos#show", as: :repo_page, constraints: {
    owner: /(?!api$)(?!git$)(?!home$)(?!search$)(?!up$)[a-z][a-z0-9-]*/,
    repo: /[a-z][a-z0-9-]*/
  }

  get ":owner", to: "owners#show", as: :owner_page, constraints: {
    owner: /(?!api$)(?!git$)(?!home$)(?!search$)(?!up$)[a-z][a-z0-9-]*/
  }
end
