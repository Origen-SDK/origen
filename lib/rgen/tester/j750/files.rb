module RGen
  module Tester
    class J750
      # Methods for handling all J750 file parsing, e.g. datalogs,
      # test time profiles, etc.
      module Files
        # Reads all lines from a J750 detailed execution time file, returning the lines
        # as an array like this:
        #
        #   [
        #     {:name => "power_cycle", :index => 1, :group => 3, :time => 0.00461},
        #     {:name => "power_cycle", :index => 2, :group => 3, :time => 0.00481},
        #     {:name => "power_cycle", :index => 3, :group => 3, :time => 0.00438},
        #     {:name => "nvm_mass_erase", :index => nil, :group => nil, :time => 0.19863},
        #   ]
        def read_test_times(file, _options = {})
          tests = []
          File.readlines(file).each do |line|
            unless line.strip.empty? || line =~ /Entire Job/
              # http://rubular.com/r/vZOcqovTsf
              if line =~ /(\w+) ?(\(.*?\))?  \d\d\d\d  (\d+\.\d+).*/
                t = { name: Regexp.last_match[1], time: Regexp.last_match[3].to_f.round(6) }
                # If an indexed test
                if Regexp.last_match[2]
                  str = Regexp.last_match[2].gsub('(', '').gsub(')', '')
                  fields = str.split('/')
                  i = fields[0].to_i
                  g = fields[1].to_i
                  t[:index] = i
                  t[:group] = g

                else
                  t[:index] = nil
                  t[:group] = nil
                end
                tests << t
              end
            end
          end
          tests
        end
      end
    end
  end
end
