module Origen
  module GlobalMethods
    require_relative 'encodings'
    # If a new gem (i.e. not part of the existing Ruby installation) is required by Origen or an
    # application then it should be required via this method.
    # On Windows this can be installed automatically and this method will take care of doing
    # that.
    #
    # However due to the restricted user permissions available on Linux this cannot be done
    # automatically and you must ensure that you arrange to have the required gem installed
    # on Linux - contact Stephen McGinty to get this done.
    #
    # A given user will then have to update their local toolset to pick this up and this method
    # will give them the necessary instructions.
    #
    # @example
    #
    #   require_gem "rest-client"
    #   require_gem "net/ldap", :name => "net-ldap"
    def require_gem(name, options = {})
      Origen.deprecate <<-END
require_gem will be removed in Origen V3, Bundler should be used to manage gem dependencies
END
      options = {
        name: name
      }.merge(options)
      name = name.to_s
      options[:name] = options[:name].to_s
      if options[:version] && options[:version] =~ /^v(.*)/
        options[:version] = Regexp.last_match[1]
      end
      # This gem was not included in the initial Origen v2.x.x gemset, so need to handle instalations
      # without it
      begin
        if options[:version]
          gem options[:name], options[:version]
        end
        require name
      rescue LoadError
        if Origen.running_on_windows?
          puts "Installing #{options[:name]}"
          command = "gem install #{options[:name]} --no-rdoc --no-ri"
          command += " --version #{options[:version]}" if options[:version]
          if !system(command)
            puts 'It looks like a problem occurred, ensure you have installed Ruby exactly per the Origen guide'
          else
            puts 'A missing gem has just been installed to your system, please re-run the previous command'
          end
        else
          puts "Installing #{options[:name]}"
          command = "gem install --user-install #{options[:name]} --no-rdoc --no-ri"
          command += " --version #{options[:version]}" if options[:version]
          if !system(command)
            puts 'It looks like there was a problem installing that gem, run the following commands to ensure you have an up to date'
            puts 'environment, then try again:'
            puts ''
            puts "  cd #{Origen.top}"
            puts '  source source_setup update'
            puts "  cd #{FileUtils.pwd}"
          else
            puts 'A missing gem has just been installed to your system, please re-run the previous command'
          end
          # puts "The current application has required a gem called #{options[:name]}, however that is not available in your current toolset."
          # puts 'This may be solved by following the instructions below, otherwise contact the application owner.'
          # puts ''
          # puts_require_latest_ruby
        end
        exit 1
      end
    end

    def annotate(msg, options = {})
      Origen.app.tester.annotate(msg, options)
    end

    def c1(msg, options = {})
      Origen.app.tester.c1(msg, options)
    end
    alias_method :cc, :c1

    def c2(msg, options = {})
      Origen.app.tester.c2(msg, options)
    end

    def ss(*args, &block)
      Origen.app.tester.ss(*args, &block)
    end
    alias_method :step_comment, :ss

    def pp(*args, &block)
      Origen.app.tester.pattern_section(*args, &block)
    end
    alias_method :pattern_section, :pp
    alias_method :ps, :pp

    def snip(*args, &block)
      Origen.app.tester.snip(*args, &block)
    end

    # Render an ERB template
    def render(*args, &block)
      Origen.generator.compiler.render(*args, &block)
    end

    # The options passed to an ERB template. Having it
    # global like this is ugly, but it does allow a hash of options
    # to always be available in templates even if the template
    # is being rendered using a custom binding.
    #
    # @api private
    def options
      $_target_options ||
        Origen.generator.compiler.options
    end

    def global_binding
      binding
    end

    def debug(*lines)
      Origen.deprecate 'debug method is deprecated, use Origen.log.debug instead'
      if Origen.debug?
        Origen.log.info ''
        c = caller[0]
        c =~ /(.*):(\d+):.*/
        $_last_log_time ||= Time.now
        delta = Time.now - $_last_log_time
        $_last_log_time = Time.now
        begin
          Origen.log.info "*** Debug *** %.6f #{Regexp.last_match[1]}:#{Regexp.last_match[2]}" % delta
        rescue
          # For this to fail it means the deprecated method was called by IRB or similar
          # and in that case there is no point advising who called anyway
        end
        options = lines.last.is_a?(Hash) ? lines.pop : {}
        lines.flatten.each do |line|
          line.split(/\n/).each do |line|
            Origen.log.info line, options
          end
        end
      end
    end

    Pattern = Origen.pattern unless defined?(Pattern)
    Flow = Origen.flow unless defined?(Flow)
    Resources = Origen.resources unless defined?(Resources)
    User = Origen::Users::User unless defined?(User)

    # Returns an Excel column based on an Integer argument
    def get_excel_column(n)
      excel_columns = {}
      @column = 'A'
      (1..75).to_a.each do |i|
        excel_columns[i] = @column
        @column = @column.succ
      end
      excel_columns[n]
    end

    # Returns the full class hierarchy of an object
    def get_full_class(obj)
      klass_str = ''
      until obj.nil?
        if obj == Origen.top_level
          klass_str.prepend obj.class.to_s
        else
          # If the class method produces "SubBlock" then use the object name instead
          if obj.class.to_s.split('::').last == 'SubBlock'
            klass_str.prepend "::#{obj.name.upcase}"
          else
            klass_str.prepend "::#{obj.class.to_s.split('::').last}"
          end
        end
        obj = obj.parent
      end
      klass_str
    end

    # Returns Rgen supported encoding formats
    def encodings(format = nil)
      if format.nil?
        Origen::ENCODINGS.keys
      else
        Origen::ENCODINGS[format].keys
      end
    end

    # Returns the encoded symbol as a String if one match is found.
    # Returns a hash for multiple results and nil for no match
    def encoding_search(symbol, options = {})
      options = {
        format: :utf8
      }.update(options)
      fail "The encoding format '#{options[:format]}' is not supported, please choose from #{encodings}" unless encodings.include? options[:format]
      results = Origen::ENCODINGS[options[:format]].filter(symbol)
      if results.size == 1
        results.values.first
      elsif results.size > 1
        results
      else
        return nil
      end
    end
  end
end
