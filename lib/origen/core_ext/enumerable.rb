module Enumerable
  PRIMATIVES = [TrueClass, FalseClass, NilClass, Integer, Float, String, Symbol, Regexp, Complex, Rational, Fixnum, Bignum]

  def debug(msg)
    Origen.log.debug(msg)
  end

  # Returns a list of primitives and/or complex objects found within an enumerable object
  # It ignores empty or nil values by default but is configurable
  # The method is recusive and will run until all enumerable objects have been examined
  def list(options = {})
    options = {
      nil_or_empty: false,
      flatten:      [], # Can be a single class or an array of classes to 'flatten' when enumerating (treated as a single value)
      select:       [], # Select certain complex data types for enumeration
      ignore:       [], # Ignore certain complex data types for enumeration
      to_s:         false # If set to true this will convert a complex object called with 'flatten' option to a String
    }.update(options)
    list_array ||= []
    [:ignore, :select, :flatten].each do |opt|
      options[opt] = [options[opt]] unless options[opt].is_a? Array
    end
    unless options[:flatten].empty? || options[:select].empty?
      fail "Cannot have the same arguments for 'flatten' and 'select' options" unless (options[:flatten] & options[:select]).empty?
    end
    unless options[:flatten].empty? || options[:ignore].empty?
      fail "Cannot have the same arguments for 'flatten' and 'ignore' options" unless (options[:flatten] & options[:ignore]).empty?
    end
    unless options[:ignore].empty? || options[:select].empty?
      fail "Cannot have the same arguments for 'ignore' and 'select' options" unless (options[:ignore] & options[:select]).empty?
    end
    if self.respond_to?(:empty?) && self.empty?
      list_array << self if options[:nil_or_empty]
    else
      each do |k, v|
        self.is_a?(Hash) ? item = v : item = k
        klass = item.class.to_s
        superklass = item.class.superclass.to_s
        if options[:flatten].include? item.class
          if item.respond_to?(:empty?)
            next if item.empty? && options[:nil_or_empty] == false
          end
          debug "Adding current enumerable #{klass} to list as a flat object, will not enumerate through it..."
          if options[:to_s] == true
            list_array << "#{superklass}::#{klass}"
          else
            list_array << item
          end
          next
        else
          next unless options[:select].empty? || options[:select].include?(item.class) || PRIMATIVES.include?(item.class)
          next if options[:ignore].include?(item.class)
          case item
          when NilClass
            list_array << item if options[:nil_or_empty]
          when Hash, Array, Range
            # debugger if item == [] && $bac == 1
            if item.empty?
              list_array << [] if options[:nil_or_empty]
            else
              list_array += item.list(options)
            end
          when Struct
            list_array += item.list(options)
          when String
            next if item.empty? && options[:nil_or_empty] == false
            list_array << item
          else
            list_array << item
          end
        end
      end
    end
    list_array
  end
end
