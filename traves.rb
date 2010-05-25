require 'active_record'
require 'config/database'
require 'lib/authorization'

class Url < ActiveRecord::Base
  before_save :generate_key
  
  validates_uniqueness_of :alias
  validates_presence_of :address
  
  def generate_key
    if self.alias.blank?
      # create a unique key
      generated_key = make_key
      
      # make SURE the key is unique (keep trying till we get it)
      while !Url.first(:conditions => ["alias = ?", generated_key]).blank?
        generated_key = make_key
      end
      
      # set the key
      self.alias = generated_key
      # self.custom = false
    else
      self.custom = true
    end
  end
  
  def shortened_url
    BASE_URL + self.alias
  end
  
  protected
    def make_key
      chars = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      key = ''
      4.times { key << chars[rand(chars.length)] }
      key
    end
end

helpers do
  include Sinatra::Authorization
end

BASE_URL = 'http://trav.es/'

get '/' do
  @url = Url.new
  erb :index
end

post '/' do
  # first things first, let's check to see if that address has already been shortened
  if params[:url][:alias].blank? and @url = Url.first(:conditions => ["address = ? AND custom = ?", params[:url][:address], false])
    erb :index
  else
    # create a new shortened url
    @url = Url.new(params[:url])
    @url.save
    erb :index
  end
end

get '/generate' do
  # make sure they are actually sending an address to shorten
  if params[:address].blank?
    redirect '/'
  end
  
  # first, try to find the url to see if it's already been shortened
  if @url = Url.first(:conditions => ["address = ? AND custom = ?", URI.unescape(params[:address]), false])
    erb :index
  else
    @url = Url.new(:address => URI.unescape(params[:address]))
    @url.save
    erb :index
  end
end

get '/error' do
  erb :error
end

get '/all-links' do
  require_admin
  @urls = Url.all
  erb :links
end

get '/:alias' do
  @url = Url.find_by_alias(params[:alias])
  if @url.blank?
    erb :error
  else
    @url.update_attribute(:num_clicks, @url.num_clicks + 1)
    redirect @url.address
  end
end