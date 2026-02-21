require 'timeout'

module Origen
  module ErrorAssistant
    module_function

    DEFAULT_TIMEOUT_SECONDS = 3.0
    DEFAULT_SITE_MODE = 'off'
    DEFAULT_PROMPT_MODE = 'default'
    DEFAULT_DISPLAY_NAME = 'Error Assistant'
    VALID_SITE_MODES = %w(off opt_in forced).freeze
    VALID_PROMPT_MODES = %w(default site_template backend_profile).freeze

    def site_mode
      raw = Origen.site_config.error_assistant_mode.to_s.strip.downcase
      VALID_SITE_MODES.include?(raw) ? raw : DEFAULT_SITE_MODE
    rescue
      DEFAULT_SITE_MODE
    end

    def app_enable_value
      return nil unless Origen.app_loaded?
      return nil unless Origen.app.respond_to?(:error_assistant_enable)

      Origen.app.error_assistant_enable
    rescue
      nil
    end

    def enabled?
      case site_mode
      when 'off'
        false
      when 'forced'
        true
      when 'opt_in'
        app_enable_value == true
      else
        false
      end
    end

    def timeout_seconds
      raw = Origen.site_config.error_assistant_timeout_seconds
      val = raw.nil? ? DEFAULT_TIMEOUT_SECONDS : raw.to_f
      val.positive? ? val : DEFAULT_TIMEOUT_SECONDS
    rescue
      DEFAULT_TIMEOUT_SECONDS
    end

    def warning_enabled?
      val = Origen.site_config.error_assistant_warning_enable
      val.nil? ? true : val == true
    rescue
      true
    end

    def prompt_mode
      raw = Origen.site_config.error_assistant_prompt_mode.to_s.strip.downcase
      VALID_PROMPT_MODES.include?(raw) ? raw : DEFAULT_PROMPT_MODE
    rescue
      DEFAULT_PROMPT_MODE
    end

    def display_name
      val = Origen.site_config.error_assistant_friendly_name
      v = val.to_s.strip
      v.empty? ? DEFAULT_DISPLAY_NAME : v
    rescue
      DEFAULT_DISPLAY_NAME
    end

    def provider_available?
      ensure_provider_loaded
      defined?(::OrigenLlm::ErrorAssistant) && ::OrigenLlm::ErrorAssistant.respond_to?(:analyze)
    end

    def analyze(exception_message:, app_stack:, app_root:)
      return nil unless enabled?
      return nil unless provider_available?

      context = {
        app_root:         app_root.to_s,
        timeout_seconds:  timeout_seconds,
        provider_mode:    Origen.site_config.error_assistant_provider_mode,
        model:            Origen.site_config.error_assistant_model,
        max_tokens:       Origen.site_config.error_assistant_max_tokens,
        temperature:      Origen.site_config.error_assistant_temperature,
        api_url:          Origen.site_config.error_assistant_api_url,
        api_key_env:      Origen.site_config.error_assistant_api_key_env,
        auth_mode:        Origen.site_config.error_assistant_auth_mode,
        auth_header_name: Origen.site_config.error_assistant_auth_header_name,
        auth_prefix:      Origen.site_config.error_assistant_auth_prefix,
        extra_headers:    Origen.site_config.error_assistant_extra_headers,
        prompt_mode:      prompt_mode,
        prompt_template:  Origen.site_config.error_assistant_prompt_template,
        backend_profile:  Origen.site_config.error_assistant_backend_profile,
        backend_context:  Origen.site_config.error_assistant_backend_context
      }

      result = Timeout.timeout(timeout_seconds) do
        ::OrigenLlm::ErrorAssistant.analyze(
          exception_message: exception_message,
          app_stack:         app_stack,
          context:           context
        )
      end

      result.is_a?(String) && !result.strip.empty? ? result.strip : nil
    rescue Timeout::Error
      warn("#{display_name} timed out after #{timeout_seconds}s")
      nil
    rescue => e
      warn("#{display_name} failed: #{e.class}: #{e.message}")
      nil
    end

    def warn(message)
      Origen.log.warn(message) if warning_enabled?
    end
    private_class_method :warn

    def ensure_provider_loaded
      return if @provider_load_attempted

      @provider_load_attempted = true
      require 'origen_llm'
    rescue LoadError
      nil
    end
    private_class_method :ensure_provider_loaded
  end
end
