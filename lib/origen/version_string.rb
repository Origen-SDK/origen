module Origen
  class VersionString < String
    include Utility::TimeAndDate
    require 'date'

    # returns version number string but strips out prefix
    def initialize(version, prefix = 'v')
      version.gsub!(/^#{prefix}/, '')  # remove leading prefix
      super(version)
    end

    # Returns a new production timestamp version string
    def self.production_timestamp
      VersionString.new("Rel#{time_now(format: :universal, include_time: false)}")
    end

    # Returns a new development timestamp version string
    def self.development_timestamp
      VersionString.new("#{User.current.initials}_#{time_now(format: :universal, underscore: true)}")
    end

    # Returns true if the version is a production tag
    def production?
      !!(self =~ /^v?\d+\.\d+\.\d+$/ || self =~ /^Rel\d+$/)
    end

    # Returns true if the version is a development tag
    def development?
      !production?
    end

    def less_than?(version)
      condition_met?("< #{version}")
    end
    alias_method :lt?, :less_than?

    def less_than_or_equal_to?(version)
      condition_met?("<= #{version}")
    end
    alias_method :lte?, :less_than_or_equal_to?

    def greater_than?(version)
      condition_met?("> #{version}")
    end
    alias_method :gt?, :greater_than?

    def greater_than_or_equal_to?(version)
      condition_met?(">= #{version}")
    end
    alias_method :gte?, :greater_than_or_equal_to?

    # Returns true if the version is a correctly formatted semantic
    # or timestamp version number
    def valid?(_options = {})
      latest? || semantic? || timestamp?
    end

    # Returns true if the version is a semantic format version number
    def semantic?
      !!(self =~ /^v?\d+\.\d+\.\d+$/ ||
         self =~ /^v?\d+\.\d+\.\d+\.(dev|pre)\d+$/
        )
    end

    def next_dev(type = :minor)
      if semantic?
        if pre
          if self =~ /dev/
            VersionString.new("#{major}.#{minor + 1}.0.pre#{pre + 1}")
          else
            VersionString.new("#{major}.#{minor}.#{tiny}.pre#{pre + 1}")
          end
        else
          case type
          when :major
            VersionString.new("#{major + 1}.0.0.pre0")
          when :minor, :development
            VersionString.new("#{major}.#{minor + 1}.0.pre0")
          when :tiny, :bugfix
            VersionString.new("#{major}.#{minor}.#{tiny + 1}.pre0")
          else
            fail "Unknown version counter type '#{type}', must be :major, :minor or :tiny"
          end
        end
      else
        VersionString.new("#{User.current.initials}_#{time_now(format: :universal, underscore: true)}")
      end
    end

    def next_prod(type = :minor)
      if semantic?
        if pre
          if self =~ /dev/
            case type
            when :major
              VersionString.new("#{major + 1}.0.0")
            when :minor, :production
              VersionString.new("#{major}.#{minor + 1}.0")
            when :tiny, :bugfix
              VersionString.new("#{major}.#{minor}.#{tiny + 1}")
            else
              fail "Unknown version counter type '#{type}', must be :major, :minor or :tiny"
            end
          else
            VersionString.new("#{major}.#{minor}.#{tiny}")
          end
        else
          case type
          when :major
            VersionString.new("#{major + 1}.0.0")
          when :minor, :production
            VersionString.new("#{major}.#{minor + 1}.0")
          when :tiny, :bugfix
            VersionString.new("#{major}.#{minor}.#{tiny + 1}")
          else
            fail "Unknown version counter type '#{type}', must be :major, :minor or :tiny"
          end
        end
      else
        VersionString.new("Rel#{time_now(format: :universal, include_time: false)}")
      end
    end

    def major
      @major ||= begin
        if semantic?
          self =~ /v?(\d+)/
          Regexp.last_match[1].to_i
        else
          fail "#{self} is not a valid semantic version number!"
        end
      end
    end

    def minor
      @minor ||= begin
        if semantic?
          self =~ /v?\d+.(\d+)/
          Regexp.last_match[1].to_i
        else
          fail "#{self} is not a valid semantic version number!"
        end
      end
    end

    def bugfix
      @bugfix ||= begin
        if semantic?
          self =~ /v?\d+.\d+.(\d+)/
          Regexp.last_match[1].to_i
        else
          fail "#{self} is not a valid semantic version number!"
        end
      end
    end
    alias_method :tiny, :bugfix

    def pre
      @pre ||= begin
        if semantic?
          if self =~ /(dev|pre)(\d+)$/
            Regexp.last_match[2].to_i
          end
        else
          fail "#{self} is not a valid semantic version number!"
        end
      end
    end
    alias_method :dev, :pre

    def latest?
      downcase == 'trunk' || downcase == 'latest'
    end

    # Returns true if the version is a timestamp format version number
    def timestamp?
      !!(self =~ /^Rel\d\d\d\d\d\d\d\d$/ ||
         self =~ /^\w\w\w?_\d\d\d\d_\d\d_\d\d_\d\d_\d\d$/)
    end

    # Returns true if the version fulfills the supplied condition.
    # Example conditions:
    #
    #   "v2.1.3"      # must equal the given version
    #   "= v2.1.3"    # alias for the above
    #   "> v2.1.3"    # must be greater than the given version
    #   ">= v2.1.3"   # must be greater than or equal to the given version
    #   "< v2.1.3"    # must be less than the given version
    #   "<= v2.1.3"   # must be less than or equal to the given version
    #   "production"  # must be a production tag
    def condition_met?(condition)
      condition = condition.to_s.strip
      if condition == 'prod' || condition == 'production'
        production?

      elsif condition =~ /^>=\s*(.*)/
        tag = validate_condition!(condition, Regexp.last_match[1])
        # Force false in the case where a production and development
        # timestamp fall on the same date. Since the production tag
        # does not contain time information it is impossible to say
        # which one is greater
        if production? != tag.production? && timestamp? &&
           to_date == tag.to_date
          false
        else
          numeric >= tag.numeric && ((self.latest? || tag.latest?) || self.timestamp? == tag.timestamp?)
        end

      elsif condition =~ /^>\s*(.*)/
        tag = validate_condition!(condition, Regexp.last_match[1])
        if production? != tag.production? && timestamp? &&
           to_date == tag.to_date
          false
        else
          numeric > tag.numeric && ((self.latest? || tag.latest?) || self.timestamp? == tag.timestamp?)
        end

      elsif condition =~ /^<=\s*(.*)/
        tag = validate_condition!(condition, Regexp.last_match[1])
        numeric <= tag.numeric && ((self.latest? || tag.latest?) || self.timestamp? == tag.timestamp?)

      elsif condition =~ /^<\s*(.*)/
        tag = validate_condition!(condition, Regexp.last_match[1])
        numeric < tag.numeric && ((self.latest? || tag.latest?) || self.timestamp? == tag.timestamp?)

      elsif condition =~ /^==?\s*(.*)/
        tag = validate_condition!(condition, Regexp.last_match[1])
        self == tag

      else
        tag = validate_condition!(condition, condition)
        self == tag
      end
    end

    # Returns a numeric representation of the version, this can be used
    # for chronological comparison with other versions
    def numeric
      if latest?
        1_000_000_000_000_000_000_000_000_000
      elsif semantic?
        # This assumes each counter will never go > 1000
        if development?
          self =~ /v?(\d+).(\d+).(\d+).(dev|pre)(\d+)/
          (Regexp.last_match[1].to_i * 1000 * 1000 * 1000) +
            (Regexp.last_match[2].to_i * 1000 * 1000) +
            (Regexp.last_match[3].to_i * 1000) +
            Regexp.last_match[5].to_i
        else
          self =~ /v?(\d+).(\d+).(\d+)/
          (Regexp.last_match[1].to_i * 1000 * 1000 * 1000) +
            (Regexp.last_match[2].to_i * 1000 * 1000) +
            (Regexp.last_match[3].to_i * 1000)
        end
      elsif timestamp?
        to_time.to_i
      else
        validate!
      end
    end

    # Returns the version as a time, only applicable for timestamps,
    # otherwise an error will be raised
    def to_time
      if latest?
        Time.new(10_000, 1, 1)
      elsif timestamp?
        if development?
          self =~ /\w+_(\d\d\d\d)_(\d\d)_(\d\d)_(\d\d)_(\d\d)$/
          Time.new(Regexp.last_match[1], Regexp.last_match[2], Regexp.last_match[3], Regexp.last_match[4], Regexp.last_match[5])
        else
          self =~ /Rel(\d\d\d\d)(\d\d)(\d\d)/
          Time.new(Regexp.last_match[1], Regexp.last_match[2], Regexp.last_match[3])
        end
      else
        fail "Version tag #{self} cannot be converted to a time!"
      end
    end

    # Returns the version as a date, only applicable for timestamps,
    # otherwise an error will be raised
    def to_date
      if latest?
        Date.new(10_000, 1, 1)
      elsif timestamp?
        to_time.to_date
      else
        fail "Version tag #{self} cannot be converted to a date!"
      end
    end

    # Validates the given condition and the extracted tag, returns the
    # tag wrapped in a VersionString if valid, will raise an error if
    # not
    def validate_condition!(condition, tag)
      tag = VersionString.new(tag)
      tag.validate!("The version condition, #{condition}, is not valid!")
      tag
    end

    # Will raise an error if the version is not valid, i.e. if valid?
    # returns false
    def validate!(msg = nil)
      unless valid?
        if msg
          fail msg
        else
          fail "The version string, #{self}, is not valid!"
        end
      end
      self
    end

    # Returns the minimum Origen version that would satisfy the given condition,
    # if the condition does not specify a minimum nil will be returned
    def self.minimum_version(condition)
      if condition =~ /^==?\s*(.*)/
        version = Regexp.last_match[1]
      elsif condition =~ /^>=\s*(.*)/
        version = Regexp.last_match[1]
      elsif condition =~ /^>\s*(.*)/
        # This is tricky to support, would probably require a lookup
        # table of all versions to be maintained
        fail 'Minimum > version is currently not supported!'
      elsif condition =~ /^<=?\s*(.*)/
        nil
      else
        version = condition
      end
      VersionString.new(version).validate! if version
    end

    # Returns the maximum Origen version that would satisfy the given condition,
    # if the condition does not specify a maximum nil will be returned
    def self.maximum_version(condition)
      if condition =~ /^==?\s*(.*)/
        version = Regexp.last_match[1]
      elsif condition =~ /^<=\s*(.*)/
        version = Regexp.last_match[1]
      elsif condition =~ /^<\s*(.*)/
        # This is tricky to support, would probably require a lookup
        # table of all versions to be maintained
        fail 'Maximum < version is currently not supported!'
      elsif condition =~ /^>=?\s*(.*)/
        nil
      else
        version = condition
      end
      VersionString.new(version).validate! if version
    end

    # Returns the version prefixed with the given value ('v' by default) if not
    # already present
    def prefixed(str = 'v')
      if self =~ /^#{str}/
        to_s
      else
        "#{str}#{self}"
      end
    end
  end
end
