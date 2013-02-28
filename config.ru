require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'em-http'
require 'json'
require 'mongo'
require 'logger'
require './app'

run Sinatra::Application
