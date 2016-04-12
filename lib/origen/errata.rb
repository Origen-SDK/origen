module Origen
  module Errata
    autoload :HwErratum,		'origen/errata/hw_erratum'
    autoload :SwErratumWorkaround,	'origen/errata/sw_erratum_workaround'
   
    attr_accessor :_errata

    # Define and instantiate an erratum object    
    def erratum(id, overview = {}, status = {}, sw_workaround = {} )
       _errata
       #@_errata[id][type] = HwErratum.new(id,type, options)
       @_errata[id] = HwErratum.new(id, overview, status, sw_workaround)
    end
  

    # Returns an erratum object with a specific id, will be modified to add other options
    def errata(options = {})
       options = {
         id:   nil
         #type: nil
       }.update(options)
       return nil if @_errata.nil?
       return nil if @_errata.empty?
       
       errata_found = Hash.new do |h, k|
         h[k] = {}
       end
       
       filter_hash(@_errata, options[:id]).each do |id, hash|
         #filter_hash(hash, options[:type]).each do |type, errata|
          # errata_found[id][type] = errata
        # end
         errata_found[id] = hash
       end
       if errata_found.empty?
         return nil
       elsif errata_found.size ==1
         errata_found.values.first #.values.first
       else
         return errata_found
       end
    end

    # Define and instantiate a sw_workaround object
    def sw_workaround(id, overview = {}, resolution = {})
      _sw_workarounds
      @_sw_workarounds[id] = SwErratumWorkaround.new(id, overview, resolution)
    end 

    # Returns a sw_workaround object with a specific id
    def sw_workarounds(options = {})
      options = {
        id: nil
      }.update(options)
      return nil if @_sw_workarounds.nil?
      return nil if @_sw_workarounds.empty?

      sw_workarounds_found = Hash.new do |h, k|
        h[k] = {}
      end
   
      filter_hash(@_sw_workarounds, options[:id]).each do |id, workarounds|
        sw_workarounds_found[id] = workarounds
      end
      if sw_workarounds_found.empty?
        return nil
      elsif sw_workarounds_found.size == 1
        sw_workarounds_found.values.first.values.first
      else
        return sw_workarounds_found
      end
    end
 
    private

    def _errata
      @_errata ||= Hash.new do |h,k|
        h[k] = {}
      end
    end
 
    def _sw_workarounds
      @_sw_workarounds ||= Hash.new do |h,k|
        h[k] = {}
      end
    end

    # Return a hash based on the filter provided
    def filter_hash(hash, filter)
      fail 'Hash argument is not a Hash!' unless hash.is_a? Hash
      filtered_hash = {}
      select_logic = case filter
        when String then 'k[Regexp.new(filter)] && k.length == filter.length'
        when (Fixnum || Integer || Float || Numeric) then "k[Regexp.new('#{filter}')]"
        when Regexp then 'k[filter]'
        when Symbol then
          'k == filter'
        when NilClass then true # Return all specs if a filter is set to nil (i.e. user doesn't care about this filter)
        else true
      end
      # rubocop:disable UnusedBlockArgument
      filtered_hash = hash.select do |k, v|
        [TrueClass, FalseClass].include?(select_logic.class) ? select_logic : eval(select_logic)
      end
      filtered_hash
    end
  end
end
