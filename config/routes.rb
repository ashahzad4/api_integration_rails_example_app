ApiExample::Application.routes.draw do

  root :to => "home#index"
  match "report" => "purchases#report"
  resources :products, :only => [:index] do
    resources :purchases, :only => [:new, :create, :show] do
      member do 
        post 'submit_verification_code'
      end
    end
  end
end
