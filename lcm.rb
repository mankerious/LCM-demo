
require 'gooddata'
require 'goodot'
require 'sinatra'
require 'slim'
require 'sinatra/base'
require 'active_support/all'
require_relative 'stuff'
require 'pp'

  configure do
    enable :logging
    file = File.new("#{settings.root}/log/#{settings.environment}.log", 'a+')
    file.sync = true
    use Rack::CommonLogger, file
  end


  
get '/' do 

  slim :index 
end


get '/settings' do


    slim :settings
end

post '/settings' do

  if params[:project].to_s == ''
    @project_pid = params[:projectid]
  else
    @project_pid = params[:project]
  end

  client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
  project = client.projects(@project_pid)
  @customer_name = params[:customer_name]
  project= project.clone(
          :title => "#{@customer_name} Master",
          :with_data => true,
          :auth_token => 'mustangs'

        )     
  @project_title = project.title

  slim :clone
end

post '/index' do


   client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
   @version='1.0.0'
   @domain=client.domain('mustangs')
   @project_pid = params[:projectid]
   @master_project = client.projects(@project_pid)
   @segment_name = params[:segment_name]
   pp @segment_name
   $segment = create_or_get_segment(@domain, @segment_name, @master_project, version: @version)
   set_master_metadata(@master_project, @version, $segment.id)

   slim :segment_details
end

post '/project' do

  	slim :project
end




post '/segment_details' do
   
   @version='1.0.0'
   client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
   @domain=client.domain('mustangs')
   # master_project = client.projects($project_pid)
   # @domain.remove_segment($segment_name)
   pp $segment.id
   create_or_get_client($segment, "acme_client1")
   @domain.synchronize_clients
   @domain.provision_client_projects

    slim :segment_details
end




post '/segments' do
   
   @version='1.0.0'
   client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
   @domain=client.domain('mustangs')
   basic_master_project = client.projects(@project_pid)
   $segment_name=params[:segment_name]
   @service_segment = create_or_get_segment(@domain, $segment_name, basic_master_project, version: @version)
   $segment_id = @service_segment.id

    slim :segment_details
end


