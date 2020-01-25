class Range
  def reverse
    first = self.first
    last = self.last
    last..first
  end

  def to_a
    a = super
    if a.empty?
      reverse.to_a.reverse
    else
      a
    end
  end

  def <=>(other)
    [min, max] <=> [other.min, other.max]
  end
end
