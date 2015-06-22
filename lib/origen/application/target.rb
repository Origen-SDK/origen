module Origen
  class Application
    # Class to handle the target.
    #
    # The target is a Ruby file that is run prior to generating each pattern, and
    # it should be used to instantiate the top-level models used by the application.
    # It can also be used to override and settings within these classes after they
    # have been instantiated and before they are run.
    #
    # All target files must live in Origen.root/target.
    #
    # An instance of this class is automatically instantiated and available globally
    # as Origen.app.target
    class Target
      DIR = "#{Origen.root}/target"        # :nodoc:
      SAVE_FILE = "#{DIR}/.default"      # :nodoc:
      DEFAULT_FILE = "#{DIR}/default.rb" # :nodoc:

      # Implement a target loop based on the supplied options.
      # The options can contain the keys :target or :targets or neither.
      #
      # In the neither case the loop will run once for the current workspace
      # default target.
      #
      # In the case where one of the keys is present the loop will run for each
      # target and the options will be passed into the block with the key :target
      # set to the current target.
      def loop(options = {})
        options = {
          set_target:  true,
          force_debug: false,  # Set true to force debug mode for all targets
        }.merge(options)
        targets = [options.delete(:target), options.delete(:targets)].flatten.compact.uniq
        targets = [file!.basename.to_s] if targets.empty?
        set = options.delete(:set_target)
        targets.each do |target|
          Origen.load_target(target, options) if set
          options[:target] = target
          yield options
        end
      end

      # Use this to implement a loop for each production target, it will automatically
      # load each target before yielding to the block.
      #
      # The production targets are defined by the production_targets configuration
      # option.
      # === Example
      #   Origen.app.target.each_production do
      #     Run something within the context of each target
      #   end
      def each_production(options = {})
        options = {
          force_debug: false,  # Set true to force debug mode for all targets
        }.merge(options)
        prod_targets.each do |moo, targets|
          [targets].flatten.each do |target|
            self.temporary = target
            Origen.app.load_target!(options)
            yield moo
          end
        end
      end

      # As each_production except it only yields unique targets. i.e. if you have two
      # MOOs that use the same target file defined in the production_targets then this
      # method will only yield once.
      #
      # An array of MOOs that use each target is returned each time.
      # === Example
      #   Origen.app.target.each_unique_production do |moos|
      #     Run something within the context of each unique target
      #   end
      def each_unique_production(options = {})
        options = {
          force_debug: false,  # Set true to force debug mode for all targets
        }.merge(options)
        targets = {}
        prod_targets.each do |moo, moos_targets|
          [moos_targets].flatten.each do |target|
            if targets[target]
              targets[target] << moo
            else
              targets[target] = [moo]
            end
          end
        end
        targets.each do |target, moos|
          self.temporary = target
          Origen.app.load_target!(options)
          yield moos
        end
      end

      # If the production_targets moo number mapping inclues the current target then
      # the MOO number will be returned, otherwise nil
      def moo
        prod_targets.each do |moo, targets|
          [targets].flatten.each do |target|
            return moo if File.basename(target, '.rb').to_s == file.basename('.rb').to_s
          end
        end
        nil
      end

      # Returns the name (the filename) of the current target
      def name
        file.basename('.rb').to_s if file
      end

      # Load the target, calling this will re-instantiate all top-level objects
      # defined there.
      def load!(options = {})
        options = {
          force_debug: false,  # Set true to force debug mode for all targets
        }.merge(options)
        Origen.app.load_target!(options)
      end

      # Returns Array of all targets available
      def all_targets
        targets = []
        find('').sort.each do |file|
          targets << File.basename(file)
        end
        targets # return
      end

      # Returns an array containing all current production targets
      def production_targets
        prod_targets.map { |_moo, targets| targets }.uniq
      end

      # Returns true if the target exists, this can be used to test for the presence
      # of a target before calling one of the other methods to actually apply it.
      #
      # It will return true if one or more targets are found matching the given name,
      # use the unique? method to test if the given name uniquely identifies a valid
      # target.
      def exists?(name)
        tgts = resolve_mapping(name)
        targets = tgts.is_a?(Array) ? tgts : find(tgts)
        targets.size > 0
      end
      alias_method :exist?, :exists?

      # Similar to the exists? method, this will return true only if the given name
      # resolves to a single valid target.
      def unique?(name)
        tgts = resolve_mapping(name)
        targets = tgts.is_a?(Array) ? tgts : find(tgts)
        targets.size == 1
      end

      # Switch to the supplied target, name can be a fragment as long as it allows
      # a unique target to be identified.
      #
      # The name can also be a MOO number mapping from the config.production_targets
      # attribute of the application.
      #
      # Calling this method does not affect the default target setting in the workspace.
      def temporary=(name)
        tgts = resolve_mapping(name)
        targets = tgts.is_a?(Array) ? tgts : find(tgts)
        if targets.size == 0
          puts "Sorry no targets were found matching '#{name}'!"
          puts 'Here are the available options:'
          find('').sort.each do |file|
            puts File.basename(file)
          end
          exit 1
        elsif targets.size > 1
          if is_a_moo_number?(name) && prod_targets
            puts "Multiple production targets exist for #{name.upcase}, use one of the following instead of the MOO number:"
            targets.sort.each do |file|
              puts File.basename(file)
            end
          else
            puts 'Please try again with one of the following targets:'
            targets.sort.each do |file|
              puts File.basename(file)
            end
          end
          exit 1
        else
          self.file = targets[0]
        end
      end
      alias_method :switch, :temporary=
      alias_method :switch_to, :temporary=

      # Returns a signature for the current target, can be used to track target
      # changes in cases where the name is not unique - i.e. when using a
      # configurable target
      def signature
        @signature ||= set_signature(nil)
      end

      # @api private
      def set_signature(options)
        options ||= {}
        @signature = options.merge(_tname: name).to_a.hash
      end

      # As #temporary= except that the given target will be set to the workspace default
      def default=(name)
        if name
          self.temporary = name
        else
          @file = nil
        end
        save
      end

      # Prints out the current target details to the command line
      def describe
        f = self.file!
        puts "Current target: #{f.basename}"
        puts '*' * 70
        File.open(f).each do |line|
          puts "  #{line}"
        end
        puts '*' * 70
      end

      # Returns an array of matching target file paths
      def find(name)
        if name
          name = name.gsub('*', '')
          if File.exist?(name)
            [name]
          elsif File.exist?("#{Origen.root}/target/#{name}") && name != ''
            ["#{Origen.root}/target/#{name}"]
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

      # Saves the current target as the workspace default, i.e. the current target
      # will be used by rGen the next time if no other target is specified
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

      # Returns the target file (a Pathname object) if it has been defined, otherwise nil
      def file # :nodoc:
        return @file if @file
        if default_file && File.exist?(default_file)
          @file = default_file
        end
      end

      # As file except will raise an exception if it hasn't been defined yet
      def file! # :nodoc:
        unless file
          puts 'No target has been specified!'
          puts 'To specify a target use the -t switch.'
          puts 'Look in the target directory for a list of available target names.'
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

      # Remove the workspace default target
      def forget
        File.delete(SAVE_FILE) if File.exist?(SAVE_FILE)
        @default_file = nil
      end

      #      # This attribute is used by the Origen#compile and Origen#merge tasks to allow files
      #      # to be compiled on a per-target basis. If the ERB source file has 'target' in the
      #      # name then this will be substituted for the value returned from this attribute. <br>
      #      # For example to simply use the MOO number to identify the target you may
      #      # set up a simple task like this:
      #      #   # Compile the J750 files for each target
      #      #   Target.each_production do
      #      #       $target.id = $target.moo.gsub("*","")
      #      #       compile("templates/j750", "j750")
      #      #   end
      #      attr_accessor :id
      #
      #      def initialize # :nodoc:
      #          restore
      #      end
      #
      #      # Yields a summary of the current target settings
      #      def summary
      #          yield "Top:      #{$top.class}"
      #          yield "SoC:      #{$soc.class}"
      #          yield "Tester:   #{$tester.class}"
      #      end

      # Returns true if running with a temporary target, i.e. if the current
      # target is not the same as the default target
      def temporary?
        @file == @default_file
      end

      # Resolves the target name to a target file if a MOO number is supplied and
      # app.config.production_targets has been defined
      def resolve_mapping(name) # :nodoc:
        if is_a_moo_number?(name) && prod_targets
          # If an exact match
          if prod_targets[name.upcase]
            prod_targets[name.upcase]
          # If a wildcard match
          elsif prod_targets["*#{moo_number_minus_revision(name)}"]
            prod_targets["*#{moo_number_minus_revision(name)}"]
          # Else just return the given name
          else
            name
          end
        else
          name
        end
      end

      # Returns config.production_targets with all keys forced to upper case
      def prod_targets # :nodoc:
        return {} unless Origen.config.production_targets
        return @prod_targets if @prod_targets
        @prod_targets = {}
        Origen.config.production_targets.each do |key, value|
          @prod_targets[key.upcase] = value
        end
        @prod_targets
      end

      # Returns true if the supplied target name is a moo number format
      def is_a_moo_number?(name) # :nodoc:
        !!(name.to_s.upcase =~ /^\d?\d?\*?[A-Z]\d\d[A-Z]$/)
      end

      def moo_number_minus_revision(name) # :nodoc:
        name.to_s.upcase =~ /^\d?\d?([A-Z]\d\d[A-Z])$/
        Regexp.last_match[1]
      end
    end
  end
end
