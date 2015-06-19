module RGen
  class Application
    # Class to control the environment.
    #
    # The environment is a Ruby file that is loaded prior to generating every piece of output.
    # It is optional, and is loaded before the target, thereby allowing targets to override
    # environment settings.
    #
    # A typical use case for the environment is to setup the test platform, or to set RGen
    # to run in debug or simulation mode. It can generally be thought of as a global target.
    #
    # All environment definition files must live in RGen.root/environment.
    #
    # An instance of this class is automatically
    # instantiated and available globally as RGen.environment.
    class Environment
      DIR = "#{RGen.root}/environment"   # :nodoc:
      SAVE_FILE = "#{DIR}/.default"      # :nodoc:
      DEFAULT_FILE = "#{DIR}/default.rb" # :nodoc:

      # Returns the name (the filename) of the current environment
      def name
        file.basename('.rb').to_s if file
      end

      # Returns Array of all environments available
      def all_environments
        envs = []
        find('').sort.each do |file|
          envs << File.basename(file)
        end
        envs
      end

      # Returns true if the environment exists, this can be used to test for the presence
      # of an environment before calling one of the other methods to actually apply it.
      #
      # It will return true if one or more environments are found matching the given name,
      # use the unique? method to test if the given name uniquely identifies a valid
      # environment.
      def exists?(name)
        envs = find(name)
        envs.size > 0
      end
      alias_method :exist?, :exists?

      # Similar to the exists? method, this will return true only if the given name
      # resolves to a single valid environment.
      def unique?(name)
        envs = find(name)
        envs.size == 1
      end

      # Switch to the supplied environment, name can be a fragment as long as it allows
      # a unique environment to be identified.
      #
      # Calling this method does not affect the default environment setting in the workspace.
      def temporary=(name)
        envs = find(name)
        if envs.size == 0
          puts "Sorry no environments were found matching '#{name}'!"
          puts 'Here are the available options:'
          find('').sort.each do |file|
            puts File.basename(file)
          end
          exit 1
        elsif envs.size > 1
          puts 'Please try again with one of the following environments:'
          envs.sort.each do |file|
            puts File.basename(file)
          end
          exit 1
        else
          self.file = envs[0]
        end
      end
      alias_method :switch, :temporary=
      alias_method :switch_to, :temporary=

      # As #temporary= except that the given environment will be set to the workspace default
      def default=(name)
        if name
          self.temporary = name
        else
          @file = nil
        end
        save
      end

      # Prints out the current environment details to the command line
      def describe
        f = self.file!
        puts "Current environment: #{f.basename}"
        puts '*' * 70
        File.open(f).each do |line|
          puts "  #{line}"
        end
        puts '*' * 70
      end

      # Returns an array of matching environment file paths
      def find(name)
        if name
          name = name.gsub('*', '')
          if File.exist?(name)
            [name]
          elsif File.exist?("#{RGen.root}/environment/#{name}") && name != ''
            ["#{RGen.root}/environment/#{name}"]
          else
            # The below weirdness is to make it recurse into symlinked directories
            Dir.glob("#{DIR}/**{,/*/**}/*").sort.uniq.select do |file|
              File.basename(file) =~ /#{name}/ && file !~ /.*\.rb.+$/
            end
          end
        else
          [nil]
        end
      end

      # Saves the current environment as the workspace default, i.e. the current environment
      # will be used by RGen the next time if no other environment is specified
      def save # :nodoc:
        if @file
          File.open(SAVE_FILE, 'w') do |f|
            Marshal.dump(file, f)
          end
        else
          forget
        end
      end

      # Load the default file from the workspace default if it exists and return it,
      # otherwise returns nil
      def default_file
        return @default_file if @default_file
        if File.exist?(SAVE_FILE)
          File.open(SAVE_FILE) do |f|
            @default_file = Marshal.load(f)
          end
        elsif File.exist?(DEFAULT_FILE)
          @default_file = Pathname.new(DEFAULT_FILE)
        end
        @default_file
      end

      # Returns the environment file (a Pathname object) if it has been defined, otherwise nil
      def file # :nodoc:
        return @file if @file
        if default_file && File.exist?(default_file)
          @file = default_file
        end
      end

      # As file except will raise an exception if it hasn't been defined yet
      def file! # :nodoc:
        unless file
          puts 'No environment has been specified!'
          puts 'To specify an environment use the -e switch.'
          puts 'Look in the environment directory for a list of available environment names.'
          exit 1
        end
        file
      end

      def file=(path) # :nodoc:
        if path
          @file = Pathname.new(path)
        else
          @file = nil
        end
      end

      # Remove the workspace default environment
      def forget
        File.delete(SAVE_FILE) if File.exist?(SAVE_FILE)
        @default_file = nil
      end

      # Returns true if running with a temporary environment, i.e. if the current
      # environment is not the same as the default environment
      def temporary?
        @file == @default_file
      end
    end
  end
end
