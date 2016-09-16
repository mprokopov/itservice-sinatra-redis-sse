# This file is part of the sinatra-sse ruby gem.
#
# Copyright (c) 2011, 2012 @radiospiel
# Distributed under the terms of the modified BSD license, see LICENSE.BSD

Dir.chdir File.dirname(__FILE__)

require "bundler/setup"
require "rack"

require "sinatra/base"
require "sinatra/reloader"
require "sinatra/sse"
require "sinatra/json"
require "sinatra/config_file"

require "redis"
#require 'em-hiredis'
require "sequel"
# require "rest-client"
require 'json'


class EventServer < Sinatra::Base
  include Sinatra::SSE
  register Sinatra::ConfigFile
  config_file 'config.yml.erb'
  set :connections, []
  set :connected_users, []
  #configure :development do
    #register Sinatra::Reloader
  #end

  #redis = Redis.new(url: "redis://localhost:6379")
  #redis = EM::Hiredis.connect("redis://localhost:6379")

  #DB = Sequel.connect('mysql2://root:@localhost:3306/itservice')
  # Sequel::Model.plugin :json_serializer
  #database_uri ="mysql2://#{ENV['MYSQL_USER']}:#{ENV['MYSQL_PASSWORD']}@#{ENV['MYSQL_HOST']}:3306/#{ENV['MYSQL_DATABASE']} " 
  #redis_uri = "redis://#{ENV['REDIS_HOST']}:6379"

  DB = Sequel.connect settings.database
  #DB = Sequel.connect database_uri

  # class Ticket < Sequel::Model
  #   many_to_one :client
  # end
  # class Client < Sequel::Model
  # end

  puts "connected to DB #{settings.database}"

  get '/channel/list' do
    # json settings.connections
    json settings.connected_users
  end
  
  get '/channel/customer/:customer' do
  end

  get '/channel/:user' do
    #redis = Redis.new(url: "redis://localhost:6379")
    puts "connected to redis #{settings.redis}"
    redis = Redis.new url: settings.redis
    #redis = Redis.new url: redis_uri
    user = DB[:users].where(id: params['user']).select(:id, :name).first
    clients = DB[:access_clients_users].where(user_id: user[:id]).map{|c| c[:client_id]}
    user_token = user[:authentication_token]

    halt unless user


    response['Access-Control-Allow-Origin'] = '*'
    sse_stream do |out|
      settings.connections << out
      settings.connected_users << user
      #redis.publish "resque:agents:online", data: user[:id]
      out.callback {
        puts 'Client disconnected from sse'
        # redis.publish "resque:agents:offline", data: user[:id]
        # redis.quit
        settings.connections.delete(out)
        settings.connected_users.delete(user)
        out.close
      }
      redis.psubscribe "ticket:*:all", "calls", "*:user-#{user[:id]}", "resque:agents:*"  do |on|
        on.psubscribe do |channel, subscriptions|
          puts "Subscribed to redis ##{channel}\n"
          #redis.publish "resque:agents:online", data: user[:id]
        end
        on.pmessage do |pattern, event, data|
          puts "#{pattern} - #{event} - #{data}"
          case pattern
          when "calls"
            puts "call from #{data}"
            out.push event: "call", data: data
          when "resque:activities:*"
            author = DB[:activities].where(id: data, author_type: 'User').select(:author_id).first
            if author && author[:author_id]
              # out.push event: "activities:agent", data: author[:author_id].to_s
              puts "new author_id #{author[:author_id]} activity #{data}"
            end
          when "resque:agents:*"
            case event
            when 'resque:agents:update'
              out.push event: event, data: data
            when 'resque:agents:online'
              out.push event: event, data: data
            when 'resque:agents:offline'
              out.push event: event, data: data
            end
          #when "notification:*:user-#{user[:id]}"
            #out.push event: event, data: data
          when "ticket:*:all"
            out.push event: event, data: data
          when "*:user-#{user[:id]}"
            out.push event: event, data: data
            #ticket = DB[:tickets].where(id: data).select(:id, :client_id).first
            #is_subscription = DB[:ticket_subscriptions].where(ticket_id: data, author_type: 'User', author_id: user[:id]).any?
            #puts "user: #{user[:id]} ticket: #{data} subscription: #{is_subscription}"
            ## counters = DB[:tickets].where(deleted_at: nil).exclude(state: ['finished','closed']).group_and_count(:type).all
            #case event
            #when 'resque:tickets:assigned'
                #out.push event: "resque:tickets:assigned", data: data if is_subscription
            #when 'resque:tickets:create'
              #if is_subscription
                #out.push event: "resque:tickets:create-notify", data: data 
              #else
                #out.push event: "resque:tickets:create", data: data
              #end
            #when 'resque:tickets:destroy'
              #out.push event: "resque:tickets:destroy", data: data
            #when 'resque:tickets:assignment-exceeded'
              #out.push event: "resque:tickets:assignment-exceeded", data: data if is_subscription
            #when 'resque:tickets:finished'
              #out.push event: "resque:tickets:finished", data: data
            #when 'resque:tickets:classification-exceeded'
              #out.push event: "resque:tickets:classification-exceeded", data: data if is_subscription
            #when 'resque:tickets:resolve-exceeded'
              #out.push event: "resque:tickets:resolve-exceeded", data: data if is_subscription
            #when 'resque:tickets:response-exceeded'
              #out.push event: "resque:tickets:response-exceeded", data: data if is_subscription
            #when 'resque:tickets:update'
              #out.push event: "resque:tickets:update", data: data
            #end if clients.include? ticket[:client_id]
            # end 
            #query = RestClient.get("http://localhost:3000/api/tickets/#{data}/can", params: {user_token: user_token})
            #if JSON.parse(query.body)["can"]
            # counters = RestClient.get("http://localhost:3000/api/tickets/counters", params: {user_token: user_token}).body
            #JSON.parse(counters).each do |c|
              #h = Hash.new
              #h[c[:type]]=c[:count]
              #out.push(data: json(h).to_s, event: 'counter') if c[:type]
            #end
            # out.push(data: counters, event: 'counter')
            # my = DB[:tickets].where(deleted_at: nil, assigned_to_id: user[:id]).exclude(state: ['finished','closed']).count
            # out.push(data: json({my: my}), event: 'counter')
          end

          if !settings.connections.include?(out)
            puts 'closing orphaned redis connection'
            redis.punsubscribe
            #redis.quit
          end
        end
      end
    end

    #redis.quit
  end
end

use Rack::CommonLogger
run EventServer.new


# Note: run
#
#   curl -s -H "Accept: text/event-stream" url
#
# to see the stream of SSE events.
