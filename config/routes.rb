# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :projects do
  resources :meetings
end

get 'meetings/:id', controller: 'meetings', :action=> 'show'