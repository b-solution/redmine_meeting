# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :projects do
  resources :meetings do
    member do
      get 'delete_conference'
      get 'join_conference'
      get 'start_conference'
    end
  end
end