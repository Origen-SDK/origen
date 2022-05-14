class Array
  def ids
    map(&:id)
  end

  def dups?
    find { |e| rindex(e) != index(e) } ? true : false
  end

  def dups
    (select { |e| rindex(e) != index(e) }).uniq
  end

  def dups_with_index
    return {} unless self.dups?

    hash = Hash.new { |h, k| h[k] = [] }
    each_with_index do |val, idx|
      hash[val] << idx
    end
    hash.delete_if { |_k, v| v.size == 1 }
    hash
  end

  def include_hash?
    each { |e| return true if e.is_a? Hash }
    false
  end

  def include_hash_with_key?(key)
    each do |e|
      if e.is_a? Hash
        return e if e.key?(key)
      end
    end
    nil
  end
end
