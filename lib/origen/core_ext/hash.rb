require 'active_support/core_ext/hash/indifferent_access'

class Hash
  def ids
    keys
  end

  # Only updates the common keys that exist in self
  def update_common(hash)
    each_key do |k|
      self[k] = hash[k] if hash.key? k
    end
  end

  # Boolean method to check if self and another hash have intersecting keys
  def intersect?(hash)
    (keys.to_set & hash.keys.to_set).empty? ? false : true
  end

  # Returns a hash containing the intersecting keys between self and another hash
  def intersections(hash)
    (keys.to_set & hash.keys.to_set).to_a
  end

  # Filter a hash by a key filter of various types
  def filter(filter)
    filtered_hash = {}
    select_logic = case filter
      when String then 'k[Regexp.new(filter)]'
      when (Fixnum || Integer || Float || Numeric) then "k[Regexp.new('#{filter}')]"
      when Regexp then 'k[filter]'
      when Symbol then 'k == filter'
      when NilClass then true
      else true
    end
    # rubocop:disable UnusedBlockArgument
    filtered_hash = select do |k, v|
      [TrueClass, FalseClass].include?(select_logic.class) ? select_logic : !!eval(select_logic)
    end
    filtered_hash
  end

  # Returns the longest key as measured by String#length
  def longest_key
    keys.map(&:to_s).max_by(&:length)
  end

  # Returns the longest key as measured by String#length
  def longest_value
    values.map(&:to_s).max_by(&:length)
  end

  def recursive_find_by_key(key)
    search_results = {} # Used to store results when key is a Regexp
    # Create a stack of hashes to search through for the needle which
    # is initially this hash
    stack = [self]
    # So long as there are more haystacks to search...
    while (to_search = stack.pop)
      # ...keep searching for this particular key...
      to_search.each do |k, v|
        # If this value can be recursively searched...
        if v.respond_to?(:recursive_find_by_key)
          # ...push that on to the list of places to search.
          stack << v
        elsif key.is_a? Regexp
          search_results[k] = v if key.match(k.to_s)
        else
          return v if (k == key)
        end
      end
    end
    if search_results.empty?
      return nil
    elsif search_results.size == 1
      return search_results.values.first
    else
      return search_results
    end
  end
end
