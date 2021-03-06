ENV['RACK_ENV'] ||= 'development'

require_relative "./models/user"
require_relative "./models/space"
require_relative "./models/request"
require_relative "./data_mapper_setup.rb"
require 'sinatra/base'
require 'sinatra/flash'

class MakersBnb < Sinatra::Base
  register Sinatra::Flash
  use Rack::MethodOverride
  enable :sessions
  set :sessions_secret, 'super secret'

  helpers do
    def current_user
      @current_user ||= User.get(session[:user_id])
    end
  end

  before do
    current_user
  end

  get '/' do
    @spaces = Space.all
    erb :"index"
  end

  post '/spaces/filter' do
    if params[:available_to] < params[:available_from]
      flash.keep[:notice] = "Unable to filter space - 'To' date is before 'From'"
      redirect('/spaces')
    else
      session[:available_from] = params[:available_from]
      session[:available_to] = params[:available_to]
      redirect'/spaces/filter'
    end
  end

  get '/spaces/filter' do
    spaces = Space.all
    date_from = session[:available_from].split("-")
    date_to = session[:available_to].split("-")
    date_f = Date.new(date_from[0].to_i, date_from[1].to_i, date_from[2].to_i)
    date_t = Date.new(date_to[0].to_i, date_to[1].to_i, date_to[2].to_i)
    @spaces = spaces.select {|space| space.available?(date_f, date_t)}
    erb(:'space/index')
  end

  delete '/sessions' do
    session[:user_id] = nil
    flash.keep[:notice] = 'You have been logged out'
    redirect '/spaces'
  end

  get '/users/:id' do
    @current_user = User.first(id: params[:id])
    erb :'user/new'
  end

  get '/users/new' do
    erb :'user/new'
  end

  post '/users/new' do
    user = User.create(email: params[:email], password: params[:password])
    session[:user_id] = user.id
    redirect '/'
  end

  get '/sessions/new' do
    erb :'sessions/new'
  end

  post '/sessions/new' do
    user = User.first(email: params[:email])
    if user
      if user.authenticated?(params[:password])
        session[:user_id] = user.id
        redirect to("/spaces")
      else
        flash.keep[:notice] = 'Wrong password'
        redirect '/sessions/new'
      end
    else
      flash.keep[:notice] = 'User does not exist'
      redirect '/sessions/new'
    end
  end

  get '/spaces' do
    @spaces = Space.all.reverse
    erb(:'space/index')
  end


  get '/spaces/new' do
    erb :'space/new'
  end

  get '/spaces/myrequests' do
    @requests = current_user.requests
    @spaces = Space.all
    erb(:'space/my_request')
  end

  get '/spaces/myincomingrequests' do
    @requests = current_user.spaces.requests
    @spaces = Space.all
    @users = User.all
    erb(:'space/my_incoming_request')
  end

  get '/spaces/:id' do
    @space = Space.get(params[:id])
    if @space.available_from > Date.today
      @min_date = @space.available_from
    else
      @min_date = Date.today
    end
    erb(:'space/space')
  end


  post '/spaces' do
    if params[:available_to] < params[:available_from]
      flash.keep[:notice] = "Unable to add space - Available to date is before available from"
      redirect('/spaces')
    else
    @space = current_user.spaces.create(name: params[:name], price: params[:price],
            description: params[:description], image_url: params[:image_url], available_from: params[:available_from],
            available_to: params[:available_to])
    erb :'space/space'
    end
  end

  post '/requests' do
    if params[:date_to] < params[:date_from]
      flash.keep[:notice] = "Unable to add space - Available to date is before available from"
      redirect('/spaces')
    else
    request = current_user.requests.new(date_from: params[:date_from], date_to: params[:date_to], space_id: params[:space_id], confirmed: false)
      if request.save
       redirect "/request/#{request.id}"
      else
      redirect '/spaces'
      end
    end
  end


  get '/request/:id' do
    @booking_request = Request.first(id: params[:id])
    @space = Space.get(@booking_request.space_id)
    erb(:'request/request')
  end

  post '/requests/confirm' do
    session[:request_id] = params[:request_id]
    redirect '/requests/confirm'
  end

  get '/requests/confirm' do
    @booking_request = Request.get( session[:request_id])
    @space = Space.get(@booking_request.space_id)
    @booking_request.update(confirmed: true)
    erb(:'request/confirm')
  end






  # start the server if ruby file executed directly
  run! if app_file == $0
end
