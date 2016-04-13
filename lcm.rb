
require 'gooddata'
require 'bundler/setup'
require 'goodot'
require 'sinatra'
require 'slim'
require 'sinatra/base'
require 'active_support/all'
require_relative 'stuff'
require_relative 'credentials'

# Enable Logging
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

    @segment_id = params[:segment_name]
    if params[:projectid] == "basic blueprint"
        puts HighLine.color('basic blueprint selected', :blue)
        VERSION = '1.0.0'
        blueprint = GoodData::Model::ProjectBlueprint.build("#{params[:segment_name]} master #{VERSION}") do |p|
          p.add_dataset('dataset.departments', title: 'Department', folder: 'Department & Employee') do |d|
            d.add_anchor('attr.departments.id', title: 'Department ID')
            d.add_label('label.departments.id', reference:'attr.departments.id', title: 'Department ID')
            d.add_label('label.departments.name', reference: 'attr.departments.id', title: 'Department Name')
            d.add_attribute('attr.departments.region', title: 'Department Region')
            d.add_label('label.departments.region', reference: 'attr.departments.region', title: 'Department Region')
          end
        end

        @client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
        @domain = @client.domain(DOMAIN)
        @master_project = @client.create_project_from_blueprint(blueprint, auth_token: TOKEN)

        load_process = redeploy_or_create_process(@master_project, './scripts/1.0.0/basic/load', name: 'load', type: :ruby)
        load_schedule = redeploy_or_create_schedule(load_process, '0 * * * *', 'main.rb', {
          name: 'load',
          params: {
            CLIENT_GDC_PROTOCOL: 'https',
            CLIENT_GDC_HOSTNAME: HOSTNAME,
          }
        })
        load_schedule.disable!

        # filters_process = redeploy_or_create_process(@master_project, 'appstore://user_filters_brick', {})
        # filters_schedule = redeploy_or_create_schedule(filters_process, load_schedule, 'main.rb', {
        #   name: 'filters',
        #   params: {
        #     input_source: "filters.csv",
        #     sync_mode: "sync_one_project_based_on_custom_id",
        #     organization: DOMAIN,
        #     CLIENT_GDC_PROTOCOL: 'https',
        #     CLIENT_GDC_HOSTNAME: HOSTNAME,
        #     filters_config: {
        #       user_column: "login",
        #       labels: [{label: "label.departments.name", "column": "department"}]
        #     }
        #   }
        # })
        # filters_schedule.disable!

        # add_users_process = redeploy_or_create_process(@master_project, 'appstore://users_brick', {})
        # add_users_schedule = redeploy_or_create_schedule(add_users_process, filters_schedule, 'main.rb', {
        #   name: 'users',
        #   params: {
        #     input_source: "users.csv",
        #     sync_mode: "sync_one_project_based_on_custom_id",
        #     organization: DOMAIN,
        #     CLIENT_GDC_PROTOCOL: 'https',
        #     CLIENT_GDC_HOSTNAME: HOSTNAME
        #   }
        # })
        # add_users_schedule.disable!

        @service_segment = create_or_get_segment(@domain, params[:segment_name], @master_project, version: VERSION)

    elsif params[:projectid] == "premium blueprint"
        puts HighLine.color('premium blueprint selected', :blue)
    else
        puts HighLine.color('neither blueprint options selected', :blue)
    end

      ###########
      # RELEASE #
      ###########
      #fix errors, can it causes 4.5 min
      # @domain.synchronize_clients
      # @domain.provision_client_projects

      # DONE
      puts HighLine.color('DONE', :green)

       slim :schedule_processes
end


#----------------------------------------------------------------------

post '/schedule_processes' do


    @client = GoodData.connect(LOGIN, PASSWORD, server: FQDN, verify_ssl: false )
    # GoodData.logging_http_on
    @domain = @client.domain(DOMAIN)
    VERSION = '1.0.0'

    ###########
    # SERVICE #
    ###########

      @service_project = @client.create_project(title: params[:service_project_name], auth_token: TOKEN)

      downloader_process = redeploy_or_create_process(@service_project, "./scripts/#{VERSION}/service/downloader", name: 'downloader', type: :ruby)
      downloader_schedule = redeploy_or_create_schedule(downloader_process, '0 * * * *', 'main.rb', {
        name: 'downloader'
      })

      transform_process = redeploy_or_create_process(@service_project, "./scripts/#{VERSION}/service/transform", name: 'transform', type: :ruby)
      transform_schedule = redeploy_or_create_schedule(transform_process, downloader_schedule, 'main.rb', {
        name: 'transform'
      })

      # association_process = redeploy_or_create_process(@service_project, 'appstore://segments_workspace_association_brick', name: 'association', type: :ruby)
      association_process = redeploy_or_create_process(@service_project, './scripts/apps/segments_workspace_association_brick', name: 'association', type: :ruby)
      association_schedule = redeploy_or_create_schedule(association_process, transform_schedule, 'main.rb', {
        name: 'association',
        params: {
          organization: DOMAIN,
          input_source: "association.csv",
          CLIENT_GDC_PROTOCOL: 'https',
          CLIENT_GDC_HOSTNAME: HOSTNAME
        }
      })

      provisioning_process = redeploy_or_create_process(@service_project, './scripts/apps/segment_provisioning_brick', name: 'provision', type: :ruby)
      provisioning_schedule = redeploy_or_create_schedule(provisioning_process, association_schedule, 'main.rb', {
        name: 'provision',
        params: {
          organization: DOMAIN,
          CLIENT_GDC_PROTOCOL: 'https',
          CLIENT_GDC_HOSTNAME: HOSTNAME
        }
      })

      # Locate user provisioning brick
      # <Errno::ENOENT: No such file or directory @ rb_sysopen - appstore://users_brick>
      # users_process = redeploy_or_create_process(@service_project, 'appstore://users_brick', name: 'users', type: :ruby)
      # users_schedule = redeploy_or_create_schedule(users_process, provisioning_schedule, 'main.rb', {
      #   name: 'users',
      #   params: {
      #     organization: DOMAIN,
      #     CLIENT_GDC_PROTOCOL: 'https',
      #     CLIENT_GDC_HOSTNAME: HOSTNAME,
      #     mode: 'add_to_organization',
      #     input_source: 'users.csv'
      #   }
      # })

      puts "Service project PID is #{@service_project.pid}"

          puts HighLine.color('DONE', :green)

          slim :provision_clients
end


post '/provision_clients' do
  
   @version='1.0.0'
   @client = GoodData.connect('mustang@gooddata.com', 'jindrisska', server: 'https://mustangs.intgdc.com', verify_ssl: false )
   @domain=@client.domain('mustangs')
   @segment = create_or_get_segment(@domain, params[:segment_id1], @master_project, version: @version)
   create_or_get_client(@segment, params[:client_name1])
   create_or_get_client(@segment, params[:client_name2])
   create_or_get_client(@segment, params[:client_name3])
   @domain.synchronize_clients
   @domain.provision_client_projects

  slim :confirmation
end

get '/confirmation' do


    slim :confirmation
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


