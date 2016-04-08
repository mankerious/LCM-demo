
require 'gooddata'
require 'goodot'
require 'sinatra'
require 'slim'
require 'sinatra/base'
require 'active_support/all'
require_relative 'stuff'

  configure do
    enable :logging
    file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    file.sync = true
    use Rack::CommonLogger, file
  end


  
get '/' do 

  slim :index 
end

post '/index' do

 	if params[:project].to_s == ''
 		$project_pid = params[:projectid]
 	else
 		$project_pid = params[:project]
	end

	client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
	project = client.projects($project_pid)
	@project_title = project.title
    $customer_name = params[:customer_name]
    
	$target=params[:button]
	if $target=="Clone Master"
  	  slim :project
  	elsif $target=="Manage Segments"
  	  slim :segments
  	end
end

post '/project' do

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

post '/segments' do
	 
	 @version='1.0.0'
     client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
     @domain=client.domain('mustangs')
     basic_master_project = client.projects($project_pid)
	 @service_segment = create_or_get_segment(@domain, 'basic', basic_master_project, version: @version)
	 $segment_id = @service_segment.id

    slim :segment_details
end