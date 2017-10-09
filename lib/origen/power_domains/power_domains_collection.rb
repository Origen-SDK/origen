module Origen
  module PowerDomains
    class PowerDomainsCollection < Hash
      def inspect(options = {})
        options = {
          fancy_output: true
        }.update(options)
        headers = []
        output_power_domain_list = []
        column_widths = {}.tap do |colhash|
          each do |domain_name, domain|
            output_attr_list = []
            domain.instance_variables.each do |attr|
              attr_getter = attr.to_s[/\@(\S+)/, 1].to_sym
              attr_val = domain.send attr_getter
              next unless [String, Numeric, Float, Integer, Symbol].include? attr_val.class
              headers << attr_getter unless headers.include?(attr_getter)
              str = case attr_val
              when Numeric
                attr_val.as_V
              when Range
                start_voltage = attr_val.first
                end_voltage = attr_val.last
                "#{start_voltage.as_V}\.\.#{end_voltage.as_V}"
              else
                attr_val.to_s
              end
              curr_longest = [attr_getter, str].max_by(&:length).size + 2 # Add 3 for the whitespace
              if colhash[attr].nil? || (colhash[attr] < curr_longest)
                colhash[attr] = curr_longest
              end
              output_attr_list << str
            end
            output_power_domain_list << output_attr_list
          end
        end
        if options[:fancy_output]
          puts '╔' + column_widths.values.each.map { |i| '═' * i }.join('╤') + '╗'
          puts '║' + headers.each_with_index.map { |col_val, i| " #{col_val} ".ljust(column_widths.values[i]) }.join('│') + '║'
          puts '╟' + column_widths.values.each.map { |i| '─' * i }.join('┼') + '╢'
          puts output_power_domain_list.each.map { |attributes| '║' + attributes.each_with_index.map { |value, attr_idx| " #{value} ".ljust(column_widths.values[attr_idx]) }.join('│') + '║' }
          puts '╚' + column_widths.values.each.map { |i| '═' * i }.join('╧') + '╝'
        else
          puts '.' + column_widths.values.each.map { |i| '-' * i }.join('-') + '.'
          puts '|' + headers.each_with_index.map { |col_val, i| " #{col_val} ".ljust(column_widths.values[i]) }.join('|') + '|'
          puts '|' + column_widths.values.each.map { |i| '-' * i }.join('+') + '|'
          puts output_power_domain_list.each.map { |attributes| '|' + attributes.each_with_index.map { |value, attr_idx| " #{value} ".ljust(column_widths.values[attr_idx]) }.join('|') + '|' }
          puts '`' + column_widths.values.each.map { |i| '-' * i }.join('-') + '\''
        end
      end
    end
  end
end
