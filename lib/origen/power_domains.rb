require 'colorize'
require_relative './power_domains/power_domain'
module Origen
  module PowerDomains
    def power_domains(expr = nil)
      if expr.nil?
        if @_power_domains.nil?
          @_power_domains = {}
        elsif @_power_domains.is_a? Hash
          if @_power_domains.empty?
            @_power_domains
          else
            @_power_domains.ids
          end
        else
          @_power_domains = {}
        end
      else
        @_power_domains.recursive_find_by_key(expr)
      end
    end

    def add_power_domain(id, options = {}, &block)
      @_power_domains ||= {}
      if @_power_domains.include?(id)
        Origen.log.error("Cannot create power domain '#{id}', it already exists!")
        fail
      end
      @_power_domains[id] = PowerDomain.new(id, options, &block)
    end
    
    # Prints the power domains to the console
    def show_power_domains(options = {})
      options = {
        fancy_output: true
      }.update(options)
      headers = []
      output_power_domain_list = []  
      column_widths = {}.tap do |colhash|
        @_power_domains.each do |domain_name, domain|
          output_attr_list = []
          domain.instance_variables.each do |attr|
            attr_getter = attr.to_s[/\@(\S+)/, 1].to_sym
            attr_val = domain.send attr_getter
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
