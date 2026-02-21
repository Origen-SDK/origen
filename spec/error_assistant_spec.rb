require 'rspec/core/version'
require 'etc'
module RSpec
  Version = Core::Version unless const_defined?(:Version)
end
require 'spec_helper'
require_relative '../lib/origen/error_assistant'

describe Origen::ErrorAssistant do
  SITE_KEYS = %w[
    error_assistant_mode
    error_assistant_timeout_seconds
    error_assistant_warning_enable
    error_assistant_friendly_name
    error_assistant_prompt_mode
    error_assistant_prompt_template
    error_assistant_backend_profile
    error_assistant_backend_context
    error_assistant_api_url
    error_assistant_provider_mode
    error_assistant_api_key_env
    error_assistant_auth_mode
    error_assistant_auth_header_name
    error_assistant_auth_prefix
    error_assistant_extra_headers
    error_assistant_model
    error_assistant_max_tokens
    error_assistant_temperature
  ].freeze

  def reset_site_keys
    SITE_KEYS.each { |k| Origen.site_config.remove_all_instances(k) }
  end

  before :each do
    reset_site_keys
    Origen.app.error_assistant_enable = nil if Origen.app.respond_to?(:error_assistant_enable=)
    Origen::ErrorAssistant.instance_variable_set(:@provider_load_attempted, nil)
  end

  it 'applies mode precedence for off/forced/opt_in' do
    Origen.site_config.add_as_highest('error_assistant_mode', 'off')
    Origen.app.error_assistant_enable = true
    expect(Origen::ErrorAssistant.enabled?).to eq(false)

    Origen.site_config.add_as_highest('error_assistant_mode', 'forced')
    Origen.app.error_assistant_enable = false
    expect(Origen::ErrorAssistant.enabled?).to eq(true)

    Origen.site_config.add_as_highest('error_assistant_mode', 'opt_in')
    Origen.app.error_assistant_enable = true
    expect(Origen::ErrorAssistant.enabled?).to eq(true)
    Origen.app.error_assistant_enable = false
    expect(Origen::ErrorAssistant.enabled?).to eq(false)
  end

  it 'falls back display name when friendly name missing' do
    expect(Origen::ErrorAssistant.display_name).to eq('Error Assistant')
    Origen.site_config.add_as_highest('error_assistant_friendly_name', 'Origen-AI')
    expect(Origen::ErrorAssistant.display_name).to eq('Origen-AI')
  end

  it 'times out best effort and returns nil' do
    Origen.site_config.add_as_highest('error_assistant_mode', 'forced')
    Origen.site_config.add_as_highest('error_assistant_timeout_seconds', 0.01)

    stub_const('OrigenLlm::ErrorAssistant', Module.new do
      def self.analyze(exception_message:, app_stack:, context:)
        sleep 0.1
        'late answer'
      end
    end)

    result = Origen::ErrorAssistant.analyze(
      exception_message: 'boom',
      app_stack: ['/tmp/app.rb:1'],
      app_root: Origen.root
    )
    expect(result).to eq(nil)
  end

  it 'passes site config settings into plugin context' do
    Origen.site_config.add_as_highest('error_assistant_mode', 'forced')
    Origen.site_config.add_as_highest('error_assistant_api_url', 'https://example.ai/assistant')
    Origen.site_config.add_as_highest('error_assistant_provider_mode', 'generic')
    Origen.site_config.add_as_highest('error_assistant_model', 'test-model')
    Origen.site_config.add_as_highest('error_assistant_max_tokens', 321)
    Origen.site_config.add_as_highest('error_assistant_temperature', 0.9)
    Origen.site_config.add_as_highest('error_assistant_api_key_env', 'ORIGEN_TEST_KEY')
    Origen.site_config.add_as_highest('error_assistant_auth_mode', 'x_api_key')
    Origen.site_config.add_as_highest('error_assistant_auth_header_name', 'X-API-Key')
    Origen.site_config.add_as_highest('error_assistant_prompt_mode', 'backend_profile')
    Origen.site_config.add_as_highest('error_assistant_backend_profile', 'origen_assistant')
    Origen.site_config.add_as_highest('error_assistant_backend_context', { 'framework' => 'origen' })
    ENV['ORIGEN_TEST_KEY'] = 'secret'

    captured_context = nil
    stub_const('OrigenLlm::ErrorAssistant', Module.new do
      define_singleton_method(:analyze) do |exception_message:, app_stack:, context:|
        captured_context = context
        'suggestion'
      end
    end)

    result = Origen::ErrorAssistant.analyze(
      exception_message: 'boom',
      app_stack: ['/tmp/app.rb:1'],
      app_root: Origen.root
    )

    expect(result).to eq('suggestion')
    expect(captured_context[:api_url]).to eq('https://example.ai/assistant')
    expect(captured_context[:provider_mode]).to eq('generic')
    expect(captured_context[:model]).to eq('test-model')
    expect(captured_context[:max_tokens]).to eq(321)
    expect(captured_context[:temperature]).to eq(0.9)
    expect(captured_context[:api_key_env]).to eq('ORIGEN_TEST_KEY')
    expect(captured_context[:auth_mode]).to eq('x_api_key')
    expect(captured_context[:auth_header_name]).to eq('X-API-Key')
    expect(captured_context[:prompt_mode]).to eq('backend_profile')
    expect(captured_context[:backend_profile]).to eq('origen_assistant')
    expect(captured_context[:backend_context]).to eq({ 'framework' => 'origen' })
  ensure
    ENV['ORIGEN_TEST_KEY'] = nil
  end

  it 'live test: raises and requests a real solution (manual)', :manual do
    unless ENV['RUN_LIVE_ERROR_ASSISTANT'] == '1'
      skip 'Set RUN_LIVE_ERROR_ASSISTANT=1 to run live endpoint test'
    end

    Origen.site_config.add_as_highest('error_assistant_mode', 'forced')
    Origen.site_config.add_as_highest('error_assistant_timeout_seconds', (ENV['ERROR_ASSISTANT_TIMEOUT_SECONDS'] || '60').to_f)
    Origen.site_config.add_as_highest('error_assistant_provider_mode', ENV['ERROR_ASSISTANT_PROVIDER_MODE'] || 'anthropic_messages')
    Origen.site_config.add_as_highest('error_assistant_api_url', ENV['ERROR_ASSISTANT_API_URL'] || 'http://llm-gateway-url')
    Origen.site_config.add_as_highest('error_assistant_model', ENV['ERROR_ASSISTANT_MODEL'] || 'claude-sonnet-4')
    Origen.site_config.add_as_highest('error_assistant_max_tokens', (ENV['ERROR_ASSISTANT_MAX_TOKENS'] || '200').to_i)
    Origen.site_config.add_as_highest('error_assistant_temperature', (ENV['ERROR_ASSISTANT_TEMPERATURE'] || '0.7').to_f)
    Origen.site_config.add_as_highest('error_assistant_auth_mode', 'ocp_apim_subscription_key')
    Origen.site_config.add_as_highest('error_assistant_api_key_env', ENV['ERROR_ASSISTANT_API_KEY_ENV'] || 'LLM_GATEWAY_KEY')
    Origen.site_config.add_as_highest('error_assistant_extra_headers', {
      'anthropic-version' => (ENV['ERROR_ASSISTANT_ANTHROPIC_VERSION'] || '2025-10-16'),
      'user' => (ENV['ERROR_ASSISTANT_USER'] || Etc.getlogin.to_s)
    })

    begin
      raise 'Live test exception for Error Assistant'
    rescue RuntimeError => e
      result = Origen::ErrorAssistant.analyze(
        exception_message: e.message,
        app_stack: Array(e.backtrace),
        app_root: Origen.root
      )

      if result.nil? || result.strip.empty?
        fail 'Live test did not return a solution. Check endpoint/auth/payload compatibility.'
      end

      puts "\n[#{Origen::ErrorAssistant.display_name} Response]\n#{result}\n"
      expect(result).to be_a(String)
      expect(result.strip).to_not eq('')
    end
  end
end
