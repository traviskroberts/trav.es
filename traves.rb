require 'mongo_mapper'
require 'yaml'
require 'lib/activerecord/lib/active_record'
require 'lib/authorization'

db_settings = YAML::load(File.new("config/database.yml").read)

MongoMapper.connection = Mongo::Connection.new('localhost')
MongoMapper.database = db_settings['database']
MongoMapper.database.authenticate(db_settings['username'], db_settings['password'])

class Url < ActiveRecord::Base
  include MongoMapper::Document
  
  key :address, String
  key :alias, String
  key :custom, Boolean, :default => false
  key :num_clicks, Integer, :default => 0
  key :created_at, DateTime
  
  before_save :generate_key
  
  validates_uniqueness_of :alias
  validates_presence_of :address
  
  def generate_key
    if self.alias.blank?
      # create a unique key
      generated_key = make_key
      
      # make SURE the key is unique (keep trying till we get it)
      while !Url.all(:alias => generated_key).blank?
        generated_key = make_key
      end
      
      # set the key
      self.alias = generated_key
    else
      self.custom = true
    end
    
    self.created_at = Time.now
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
  if params[:url][:alias].blank? and @url = Url.first(:address => params[:url][:address], :custom => false)
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
  
  unescaped_address = URI.unescape(params[:address])
  
  # first, try to find the url to see if it's already been shortened
  if @url = Url.first(:address => unescaped_address, :custom => false)
    erb :index
  else
    @url = Url.new(:address => unescaped_address)
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
  @url = Url.first(:alias => params[:alias])
  
  if @url.address
    @url.num_clicks += 1
    @url.save
    redirect @url.address
  else
    erb :error
  end
end