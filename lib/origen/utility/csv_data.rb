module Origen
  module Utility
    # A class to handle the parsing of Comma Separated Value (CSV) input data
    # Field names are indicated on first line of file, separated by comma
    # Field values are indicated on all lines after first line of file, separated by comma
    # All lines must have same number of fields names and values
    class CSV
      # Supply a path to the CSV file, this should be a relative path from the top
      # level of your project workspace (Origen.root)
      def initialize(file)
        @file = file
      end

      # Parses the CSV file and returns an array of hashes where each hash represents
      # one line of data. Hash keys obtained from first line of field names.
      # Optionally if block supplied, it will return a single line from CSV file at a time
      #
      # ==== Example
      #   csv = CSV.new("/path/to/data.csv")
      #
      #   Process data yourself
      #   data = csv.parse
      #   data.each do |dataline|
      #      dataline.keys.each do |key|
      #        print "Key: #{key}, Value: #{dataline[key]}\n"
      #      end
      #   end
      #
      #   Let parse process data (not much diff)
      #   csv.parse do |dataline|
      #      dataline.keys.each do |key|
      #        print "Key: #{key}, Value: #{dataline[key]}\n"
      #      end
      #   end
      def parse(options = {})
        csv_data = extract_csv_data(options)
        if block_given?  # doesn't do much at this point
          csv_data.each do |dataset|
            yield dataset
          end
        else
          csv_data
        end
      end

      # Parses the data and returns only the field values (keys)
      # defined in the first line of the file
      # opens file but only reads first line
      # ==== Example
      #   csv = CSV.new("/path/to/data.csv")
      #   field_names = csv.fields
      #
      def fields
        extract_csv_data(field_names_only: true)
      end

      # Number of fields in file
      def num_fields
        fields.length
      end

      # Checks fields to ensure they exist
      # Input: array of fields expected
      def valid_fields?(check_fields = [])
        fields.eql?(check_fields)
      end

      private

      # Returns an array containing all data from given CSV file
      def extract_csv_data(options = {}) # :nodoc:
        options = { field_names_only: false,  # whether to obtain field names only
                    comment_char:     '#',        # ignore lines that start with comment character
                  }.merge(options)

        field_names = []
        field_values = []
        result = []
        line_no = 1
        File.readlines("#{Origen.root}/#{@file}").each do |line|
          # Clean up line
          line.strip!
          if line =~ /^#{options[:comment_char]}/
            line_no = 1   # reset line counter
            next          # skip comment lines
          end
          if line_no == 1 # Field names
            field_names = line.split(',')
          else  # Field values
            field_values = line.split(',')
            if field_names.length != field_values.length
              abort "ERROR! Invalid number of fields (#{field_values.length}) in CVS file on line # #{line_no}. Should be #{field_names.length}.\n"
            end
            temp_data = {}
            field_names.each_index do |index|
              temp_data[field_names[index]] = field_values[index]
            end
            result.push(temp_data)
          end
          if options[:field_names_only]
            result = field_names
            break # abort loop
          end
          line_no += 1
        end
        result
      end
    end
  end
end
