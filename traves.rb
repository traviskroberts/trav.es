# require 'rubygems'
# require 'sinatra'
require 'active_record'
require 'config/database'

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

BASE_URL = 'http://trav.es/'

get '/' do
  @url = Url.new
  erb :index
end

post '/' do
  # first things first, let's check to see if that address has already been shortened
  if params[:url][:alias].blank? and @url = Url.first(:conditions => ["address = ? AND custom = ?", params[:url][:address], false])
    redirect "/link/#{@url.id}"
  end
  
  # create a new shortened url
  @url = Url.new(params[:url])
  @url.save
  
  erb :index
end

get '/:alias' do
  @url = Url.find_by_alias(params[:alias])
  if @url.blank?
  else
    redirect @url.address
  end
end