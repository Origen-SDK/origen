require 'colorize'
module Origen
  module Clocks
    class ClocksCollection < Hash
      ConsoleValue = Struct.new(:value, :color)

      def inspect(options = {})
        options = {
          fancy_output: true
        }.update(options)
        headers = []
        output_clock_list = []
        column_widths = {}.tap do |colhash|
          each do |clk_name, clk|
            output_attr_list = {}
            clk.instance_variables.each do |attr|
              value_color = :default
              attr_getter = attr.to_s[/\@(\S+)/, 1].to_sym
              attr_val = clk.send attr_getter
              next unless [String, Numeric, Float, Integer, Symbol, Range].include? attr_val.class

              headers << attr_getter unless headers.include?(attr_getter)
              str = case attr_val
              when Numeric
                value_color = :red unless clk.setpoint_ok?(attr_val)
                attr_val.as_Hz
              when Range
                start_frequency = attr_val.first
                end_frequency = attr_val.last
                "#{start_frequency.as_Hz}\.\.#{end_frequency.as_Hz}"
              else
                attr_val.to_s
              end
              curr_longest = [attr_getter, str].max_by(&:length).size + 2 # Add 2 for the whitespace
              if colhash[attr].nil? || (colhash[attr] < curr_longest)
                colhash[attr] = curr_longest
              end
              output_attr_list[attr_getter] = ConsoleValue.new(str, value_color)
            end
            output_clock_list << output_attr_list
          end
        end
        # Need to loop through the clock table values and find nils
        # and create ConsoleValue instances for them
        updated_clock_list = [].tap do |clk_ary|
          output_clock_list.each do |attrs|
            temp_hash = {}.tap do |tmphash|
              headers.each do |h|
                if attrs[h].nil?
                  tmphash[h] = ConsoleValue.new('', :default)
                else
                  tmphash[h] = ConsoleValue.new(attrs[h].value, attrs[h].color)
                end
              end
            end
            clk_ary << temp_hash
          end
        end
        if options[:fancy_output]
          puts '╔' + column_widths.values.each.map { |i| '═' * i }.join('╤') + '╗'
          puts '║' + headers.each_with_index.map { |col_val, i| " #{col_val} ".ljust(column_widths.values[i]) }.join('│') + '║'
          puts '╟' + column_widths.values.each.map { |i| '─' * i }.join('┼') + '╢'
          puts updated_clock_list.each.map { |attributes| '║' + headers.each_with_index.map { |value, attr_idx| attributes[value].color == :default ? " #{attributes[value].value} ".ljust(column_widths.values[attr_idx]) : " #{attributes[value].value} ".ljust(column_widths.values[attr_idx]).colorize(:red) }.join('│') + '║' }
          puts '╚' + column_widths.values.each.map { |i| '═' * i }.join('╧') + '╝'
        else
          puts '.' + column_widths.values.each.map { |i| '-' * i }.join('-') + '.'
          puts '|' + headers.each_with_index.map { |col_val, i| " #{col_val} ".ljust(column_widths.values[i]) }.join('|') + '|'
          puts '|' + column_widths.values.each.map { |i| '-' * i }.join('+') + '|'
          puts updated_clock_list.each.map { |attributes| '|' + headers.each_with_index.map { |value, attr_idx| attributes[value].color == :default ? " #{attributes[value]} ".ljust(column_widths.values[attr_idx]) : " #{attributes[value]} ".ljust(column_widths.values[attr_idx]).colorize(:red) }.join('|') + '|' }
          puts '`' + column_widths.values.each.map { |i| '-' * i }.join('-') + '\''
        end
      end
    end
  end
end
