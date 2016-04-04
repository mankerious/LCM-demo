
require 'gooddata'
require 'pp'
require 'sinatra'
require 'slim'
require 'sinatra/base'
# A toolkit of support libraries and Ruby core extensions extracted from the Rails framework. Rich support for multibyte strings, internationalization, time zones, and testing.
require 'active_support/all'

# reference: http://www.sitepoint.com/just-do-it-learn-sinatra-i/
  configure do
    enable :logging
    file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    file.sync = true
    use Rack::CommonLogger, file
  end

get '/' do 
#	@project_list=""
	#get a list of projects for this user and display them
	# GoodData.with_connection() do |client|
 #    	client.projects.each do |project|
 #        	@project_list =  @project_list + project.title
 #    	end
	# end
  slim :index 
end


post '/' do

 	if params[:project].to_s == ''
 		@project_pid = params[:projectid]
 	else
 		@project_pid = params[:project]
	end

	client = GoodData.connect()
	project = client.projects(@project_pid)
	@project_title = project.title


  	slim :project
end


