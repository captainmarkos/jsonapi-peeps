Rails.application.routes.draw do
  # Defines the root path route ("/")
  # root "articles#index"

  namespace :api do
    namespace :v1 do
      #resources :campgrounds do
      #  resources :campsites
      #end

      jsonapi_resources :contacts
      jsonapi_resources :phone_numbers
    end
  end


  #jsonapi_resources :contacts
  #jsonapi_resources :phone_numbers
end
