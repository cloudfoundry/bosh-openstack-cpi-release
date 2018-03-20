require_relative './spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  include Bosh::OpenStackCloud::Helpers

  before(:all) do
    @config = IntegrationConfig.new
    Bosh::Clouds::Config.configure(OpenStruct.new(logger: @config.logger, cpi_task_log: nil))
  end

  let(:logger) { @config.logger }

  before do
    delegate = double('delegate', logger: logger, cpi_task_log: nil)
    Bosh::Clouds::Config.configure(delegate)
    allow(Bosh::Clouds::Config).to receive(:logger).and_return(logger)
  end

  describe 'Glance version discovery' do
    context 'when only V1 is available' do
      before do
        force_image_v1
      end

      it 'CPI uses V1' do
        expect(@config.create_cpi.glance.class.to_s).to start_with('Fog::Image::OpenStack::V1')
      end
    end

    context 'when V2 is available' do
      it 'CPI uses V2' do
        expect(@config.create_cpi.glance.class.to_s).to start_with('Fog::Image::OpenStack::V2')
      end
    end
  end

  describe 'Cinder version discovery' do
    context 'when only V1 is available' do
      before do
        force_volume_v1
      end

      it 'CPI uses V1' do
        expect(@config.create_cpi.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V1')
      end
    end

    context 'when V2 is available' do
      it 'CPI uses V2' do
        expect(@config.create_cpi.volume.class.to_s).to start_with('Fog::Volume::OpenStack::V2')
      end
    end
  end

  def force_image_v1
    service_catalog = retrieve_catalog
    image_url = find_service_url(service_catalog, 'image')
    stub_root_service_versions(image_url) do |versions|
      filtered_versions = versions.select { |v| v['id'].start_with?('v1.') }.reject { |v| v['status'] == 'DEPRECATED' }
      if filtered_versions.empty?
        pending 'Image is not available in version v1.'
        raise
      end
      filtered_versions
    end
  end

  def force_volume_v1
    volume_v1_type = 'volume'
    service_catalog = stub_service_catalog do |service_catalog|
      service_catalog.reject { |service| service['type'].start_with?('volume') && service['type'] != volume_v1_type }
    end

    volume_url = find_service_url(service_catalog, volume_v1_type)

    stub_root_service_versions(volume_url) do |versions|
      versions.select { |v| v['id'].start_with?('v1.') }
    end
  end

  def stub_service_catalog
    token = retrieve_token
    filtered_catalog = yield get_catalog(token)
    filtered_token = set_response_catalog(filtered_catalog, token)

    expected_status = is_v3(@config.auth_url) ? 201 : 200

    stub_request(:post, token_uri(@config.auth_url)).to_return(body: filtered_token.to_json, status: expected_status)

    filtered_catalog
  end

  def find_service_url(service_catalog, service_type)
    endpoints = service_catalog.find { |service| service['type'] == service_type }['endpoints']
    if is_v3(@config.auth_url)
      endpoints.find { |endpoint| endpoint['interface'] == 'public' }['url']
    else
      endpoints.first['publicURL']
    end
  end

  def retrieve_catalog
    token = retrieve_token
    get_catalog(token)
  end

  def get_catalog(token)
    if is_v3(@config.auth_url)
      token['token']['catalog']
    else
      token['access']['serviceCatalog']
    end
  end

  def set_response_catalog(catalog, response)
    if is_v3(@config.auth_url)
      response['token']['catalog'] = catalog
    else
      response['access']['serviceCatalog'] = catalog
    end
    response
  end

  def retrieve_token
    token_response_uri = token_uri(@config.auth_url)
    http = create_http_connection(token_response_uri)
    token_request = Net::HTTP::Post.new(token_response_uri.request_uri, 'Content-Type' => 'application/json')
    token_request.body = if is_v3(@config.auth_url)
                           {
                             'auth' => {
                               identity: {
                                 methods: ['password'],
                                 password: {
                                   user: {
                                     password: @config.api_key,
                                     domain: {
                                       name: @config.domain,
                                     },
                                     name: @config.username,
                                   },
                                 },
                               },
                               scope: {
                                 project: {
                                   name: @config.project,
                                   domain: {
                                     name: @config.domain,
                                   },
                                 },
                               },
                             },
                           }.to_json
                         else
                           {
                             'auth' => {
                               'tenantName' => @config.tenant,
                               'passwordCredentials' => {
                                 'username' => @config.username,
                                 'password' => @config.api_key,
                               },
                             },
                           }.to_json
    end
    token_response = http.request(token_request)
    JSON.parse(token_response.body)
  end

  def token_uri(auth_url)
    token_response_uri = URI.parse(auth_url)

    token_response_uri.path = if is_v3(auth_url)
                                '/v3/auth/tokens'
                              else
                                '/v2.0/tokens'
                              end

    token_response_uri
  end

  def is_v3(auth_url)
    auth_url.match(/\/v3(?=\/|$)/)
  end

  def stub_root_service_versions(service_url)
    supported_versions_uri = URI.parse(service_url)
    supported_versions_uri.path = ''

    http = create_http_connection(supported_versions_uri)
    supported_versions_resp = http.request(Net::HTTP::Get.new(supported_versions_uri.request_uri))
    supported_versions = JSON.parse(supported_versions_resp.body)
    supported_versions['versions'] = yield supported_versions['versions']

    stub_request(:get, supported_versions_uri)
      .to_return(body: supported_versions.to_json, status: 200)
  end

  def create_http_connection(token_response_uri)
    ssl_options = { use_ssl: token_response_uri.scheme == 'https' }
    if @config.ca_cert_path
      ssl_options[:ca_file] = @config.ca_cert_path
    elsif @config.insecure
      ssl_options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
    end
    Net::HTTP.start(token_response_uri.host, token_response_uri.port, ssl_options)
  end
end
