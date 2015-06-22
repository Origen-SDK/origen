module Origen
  module Tester
    # Class for handling test time analysis - implements the functionality
    # exposed via the 'origen time' command
    class Time
      require 'yaml'

      TT_LIB_DIR  = "#{Origen.root}/config/test_time/lib"
      TT_FLOW_DIR = "#{Origen.root}/config/test_time/flow"
      DEFAULT_LIBRARY = "#{TT_LIB_DIR}/default.yaml"
      DEFAULT_FLOW    = "#{TT_FLOW_DIR}/default.yaml"

      # If any new embedded hashes are added to this a default of {} must also be added
      # to the sanitize method
      TEST_META_DATA = { 'rule'      => nil,
                         'reference' => { 'rule_result' => nil,
                                          'time'        => nil,
                                          'target'      => nil
                                        }
                       }

      def stats
        @stats ||= { imported: 0, rules_assigned: 0, reference_rules_evaluated: 0 }
      end

      def clear_stats
        @stats = nil
      end

      # Import a flow, this can be from either a datalog or an execution time
      def import_test_flow(file, options = {})
        clear_stats
        @options = options
        if Origen.tester.respond_to?('read_test_times')
          tests = Origen.tester.read_test_times(file, options)
          flow = []
          merge_indexed_tests(tests) do |name, _attrs|
            if import?(name)
              Origen.log.info "imported... #{name}"
              flow << name
            end
          end
          puts ''
          puts 'Import complete!'
          puts ''
          export_flow(flow, options)
        else
          error 'Sorry, no test time import method is defined for the current tester'
        end
      end

      def import_test_time(file, options = {})
        clear_stats
        @options = options
        if Origen.tester.respond_to?('read_test_times')
          tests = Origen.tester.read_test_times(file, options)
          total = extract_total_time(tests)
          flow = []
          library = {}
          imported = 0.0
          merge_indexed_tests(tests) do |name, attrs|
            attrs = sanitize(attrs)

            if import?(name)
              Origen.log.info "importing... #{name}"
              flow << name
              if library[name]
                library[name] = merge(library[name], attrs)
              else
                library[name] = populate(name, attrs)
                stats[:imported] += 1
              end
              imported += attrs['reference']['time']
              # puts name
            end
          end
          puts ''
          puts 'Import complete!'
          puts ''
          puts 'Some stats...'
          puts ''
          puts "Tests imported:        #{stats[:imported]}"
          puts "Rules assigned:        #{stats[:rules_assigned]}"
          puts "Ref rules calculated:  #{stats[:reference_rules_evaluated]}"
          puts ''
          puts 'Total time:            ' + total.round(6).to_s + 's'
          puts 'Total filtered time:   ' + imported.round(6).to_s + 's'
          if stats[:imported] == stats[:rules_assigned]
            puts 'Forecasted:            ' + calculate_time(flow, library, options.merge(silent: true)).to_s + 's'
          else
            puts 'Forecasted:            SOME TESTS HAVE NO RULES ASSIGNED!'
          end
          puts ''
          export_library(library, options)
        else
          error 'Sorry, no test time import method is defined for the current tester'
        end
      end

      def forecast_test_time(options = {})
        clear_stats
        @options = options
        time = 0.0
        flow = import_flow(input_flow_file(options))
        library = import_library(input_library_file(options))['tests']
        calculate_time(flow, library, options)
      end

      def output_library_file(options = {})
        if options[:ref_name]
          "#{TT_LIB_DIR}/#{options[:ref_name]}.yaml"
        else
          DEFAULT_LIBRARY
        end
      end

      def input_library_file(options = {})
        output_library_file(options)
      end

      def output_flow_file(options = {})
        if options[:ref_name]
          "#{TT_FLOW_DIR}/#{options[:ref_name]}.yaml"
        else
          DEFAULT_FLOW
        end
      end

      def input_flow_file(options = {})
        output_flow_file(options)
      end

      # Force the imported test data from the tester into a YAML compliant form
      def sanitize(attrs)
        # Force all keys to strings...
        attrs.keys.each do |key|
          begin
            attrs[key.to_s] = attrs.delete(key)
          rescue
            # No problem
          end
        end
        attrs['reference'] ||= {}
        # attrs["opportunity"] ||= {}
        if attrs['time']
          attrs['reference']['time'] = attrs.delete('time')
        end
        deep_merge(TEST_META_DATA, attrs)
      end

      # Populate the attributes based on user specified rules
      def populate(name, attrs, options = {})
        if rules
          r = rules.assign(name, attrs, options)
          if r
            stats[:rules_assigned] += 1
            attrs['rule'] = r
          else
            warn "No rule assigned to: #{name}"
            attrs.delete('rule')
          end
          r = rules.evaluate(name, attrs, options)
          if r
            stats[:reference_rules_evaluated] += 1
            attrs['reference']['rule_result'] = r
          else
            warn "No reference rule result assigned to: #{name}"
            attrs['reference'].delete('rule_result')
          end
        end
        attrs['reference']['target'] = Origen.target.name
        attrs
      end

      def export_library(lib, options = {})
        tests = {}
        lib.each do |name, attrs|
          tests[name] = attrs
        end
        Origen.file_handler.open_for_write(output_library_file(options)) do |f|
          f.puts YAML.dump('tests' => tests)
        end
        puts "Test library exported to: #{Origen.file_handler.relative_path_to(output_library_file(options))}"
      end

      def import_library(lib, _options = {})
        YAML.load(File.open(lib))
      end

      def export_flow(flow, options = {})
        Origen.file_handler.open_for_write(output_flow_file(options)) do |f|
          f.puts YAML.dump(flow)
        end
        puts "Test flow exported to: #{Origen.file_handler.relative_path_to(output_flow_file(options))}"
      end

      def import_flow(flow, _options = {})
        YAML.load(File.open(flow))
      end

      # Deep merge two hashes, the first one should be the defaults, the second one will override any
      # items from the defaults
      def deep_merge(hash1, hash2)
        hash1.merge(hash2) do |_key, oldval, newval|
          oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
          newval = newval.to_hash if newval.respond_to?(:to_hash)
          oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? deep_merge(oldval, newval) : newval
        end
      end

      # Merge two sets of attributes for the same test, generally this means that the time will
      # be averaged and all other attributes will remain the same
      def merge(t1, t2)
        t1['reference']['time'] = (t1['reference']['time'] + t2['reference']['time']) / 2
        t1
      end

      # Calculate the time for the given flow, using times from the given library
      def calculate_time(flow, library, options = {})
        options = {
          silent:  false,
          summary: false
        }.merge(options)
        unless options[:silent] || options[:summary]
          Origen.log.info 'Test'.ljust(60) + 'Rule'.ljust(40) +
            library.first[1]['reference']['target'].ljust(30) + Origen.target.name
          orig = 0
        end
        forecasted = flow.reduce(0.0) do  |sum, test|
          if library[test]['include'] == false || library[test]['exclude'] == true
            sum
          else
            orig += library[test]['reference']['time'] unless options[:silent] || options[:summary]
            forecast = rules.forecast(test, library[test], options)
            unless options[:silent] || options[:summary]
              Origen.log.info test.ljust(60) + library[test]['rule'].to_s.ljust(40) +
                              "#{library[test]['reference']['time'].round(6)}".ljust(30) +
                              "#{forecast.round(6)}"
            end
            sum + forecast
          end
        end
        if options[:silent]
          forecasted.round(6)
        elsif options[:summary]
          Origen.log.info Origen.target.name.ljust(50) + "#{forecasted.round(6)}"
        else
          Origen.log.info ''
          Origen.log.info ''.ljust(100) + '---------------'.ljust(30) + '---------------'
          Origen.log.info ''.ljust(100) + "#{orig.round(6)}".ljust(30) + "#{forecasted.round(6)}"
          Origen.log.info ''.ljust(100) + '---------------'.ljust(30) + '==============='
          Origen.log.info ''
        end
      end

      def extract_total_time(tests)
        tests.reduce(0.0) { |sum, test| sum + test[:time] }
      end

      # This combines the test time from indexed tests and removes the :index and :group keys from all tests.
      #
      # If it is an indexed test then a single hash will be returned containing the total time and the key:
      # {:indexed => true}.
      def merge_indexed_tests(tests)
        ix_counter = false
        ix_group = false
        ix_test = false
        ix_total = false

        tests.each do |t|
          i = t.delete(:index)
          g = t.delete(:group)
          process = true
          if ix_counter
            if ix_test == t[:name]
              process = false
              warning "Incomplete index data from test: #{ix_test}" if i != ix_counter + 1
              ix_counter = i
              ix_total += t[:time]
              # If the last test in the index
              if i == ix_group
                yield(ix_test, { time: ix_total, indexed: true })
                ix_counter = false
              end
            else
              warning "Incomplete index data from test: #{ix_test}"
              yield(ix_test, { time: ix_total, indexed: true })
              ix_counter = false
            end
          end
          # Don't combine this with the above via an else, it is required to be separate to generate the
          # next entry in the case where an index group was incomplete
          if process
            if i
              # Ignore tests with an invalid index and a very short time, these occur from tests which
              # are in the flow, but have not been executed in this run
              unless i != 1 && t[:time] < 0.0001
                ix_counter = i
                ix_group = g
                ix_test = t[:name]
                ix_total = t[:time]
                warning "Incomplete index data from test: #{t[:name]}" if ix_counter != 1
              end
            else
              yield t.delete(:name), t
            end
          end
        end
      end

      def import?(test)
        if filter
          filter.import?(test)
        else
          true
        end
      end

      def filter
        return @filter if defined?(@filter)
        if defined?(TestTimeFilter)
          @filter = TestTimeFilter.new
        else
          @filter = false
        end
      end

      def rules
        return @rules if defined?(@rules)
        if defined?(TestTimeRules)
          @rules = TestTimeRules.new
        else
          @rules = false
        end
      end
    end
  end
end
