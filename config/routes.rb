Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA manifest (installable app, research R11). The service worker stays off for now.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Home: search box, the reader's collection and the newest books (002 contracts/http.md).
  # Signed-out visitors are sent to sign-in by ApplicationController.
  root "home#show"
  get "home", to: "home#show", as: :home
  resources :recent_books, only: :index

  # :id / :book_id is the book's public_id (Book#to_param).
  resources :books, only: %i[ index show ] do
    scope module: :books do
      resource :reader, only: :show, path: "read"
      resource :file, only: :show
      resource :reading_position, only: :update
      resource :reading_direction, only: :update
      resource :library_entry, only: %i[ create destroy ]
      resource :favorite, only: %i[ create destroy ]
      resources :reviews, only: %i[ index create ]
    end
  end
  resources :reviews, only: %i[ edit update destroy ]
  resource :reading_settings, only: %i[ edit update ]
end
