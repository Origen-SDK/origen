module Origen
  module Errata
    autoload :HwErratum,		'origen/errata/hw_erratum'
    autoload :SwErratumWorkaround,	'origen/errata/sw_erratum_workaround'
   
    attr_accessor :_errata

    attr_accessor :_sw_workarounds

    # Define and instantiate an erratum object    
    def erratum(id, ip_block, overview = {}, status = {}, sw_workaround = {} )
       _errata
       @_errata[id][ip_block][status[:disposition]] = HwErratum.new(id, ip_block, overview, status, sw_workaround)
    end
  

    # Returns an erratum or list of erratum that meet a specific criteria
    def errata(options = {})
       options = {
         id:   nil,
         ip_block: nil,
         disposition: nil
       }.update(options)
       return nil if @_errata.nil?
       return nil if @_errata.empty?
       
       errata_found = Hash.new do |h, k|
         h[k] = Hash.new do |hh, kk|
           hh[kk] = {}
         end 
       end
      
       # First filter on id, then ip_block, then disposition
       filter_hash(@_errata, options[:id]).each do |id, hash|
         filter_hash(hash, options[:ip_block]).each do |ip_block, hash1|
           filter_hash(hash1, options[:disposition]).each do |disposition, errata|
             errata_found[id][ip_block][disposition] = errata
           end
         end
       end

       # Return nil if there are no errata that meet criteria
       if errata_found.empty?
         return nil
       # If only one errata meets criteria, return that HwErratum object
       elsif errata_found.size ==1
         errata_found.values.first.values.first.values.first
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
   
      # filter on id
      filter_hash(@_sw_workarounds, options[:id]).each do |id, workarounds|
        sw_workarounds_found[id] = workarounds
      end
      if sw_workarounds_found.empty?
        return nil
      elsif sw_workarounds_found.size == 1
        sw_workarounds_found.values.first #.values.first
      else
        return sw_workarounds_found
      end
    end
 
    private

    def _errata
      @_errata ||= Hash.new do |h,k|
        h[k] = Hash.new do |hh, kk|
          hh[kk] = {}
         end
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
