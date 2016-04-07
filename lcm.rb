
require 'gooddata'
require 'pp'
require 'sinatra'
require 'slim'
require 'sinatra/base'
require 'active_support/all'

  configure do
    enable :logging
    file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    file.sync = true
    use Rack::CommonLogger, file
  end

get '/' do 

  slim :index 
end


post '/project' do

 	if params[:project].to_s == ''
 		$project_pid = params[:projectid]
 	else
 		$project_pid = params[:project]
	end

	client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
	project = client.projects($project_pid)
	@project_title = project.title
  $customer_name = params[:customer_name]


  	slim :project
end

post '/clone' do

     client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
     project = client.projects($project_pid)
     project= project.clone(
          :title => "#{$customer_name} Master - #{project.title}",
          :with_data => true,
          :auth_token => 'mustangs'
        )     

    slim :clone
end
