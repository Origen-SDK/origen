module Origen
  module Chips
    autoload :Chip, 'origen/chips/chip.rb'
    autoload :Design_Entry, 'origen/chips/design_entry.rb'
    autoload :Doc_Entry, 'origen/chips/doc_entry.rb'
    autoload :RSS_Note, 'origen/chips/note.rb'

    attr_accessor :_chips, :_designs, :_docs, :_notes

    SPEC_TYPES = [:dc, :ac, :temperature, :supply]

    NOTE_TYPES = [:spec, :doc, :mode, :feature, :sighting]

    SpecTableAttr = Struct.new(:table_text, :show, :padding)

    # A regular Array but print specs to the console via their ID for brevity and
    # consistency with other APIs (e.g. $dut.regs  # => [:reg1, :reg2])
    class ChipArray < Array
      def inspect
        map(&:name).inspect
      end
    end

    # Returns a hash of hash containing all specs/modes
    # If no spec is specified then all specs are returned via inspect
    # If a spec is specified, a spec object will be returned if found
    # in the current mode.  If a mode option is passed and no spec
    # is passed it will filter the specs inspect display by the mode
    # and visa-versa
    def chips(s = nil, options = {})
      options = {
        group:       nil,
        family:      nil,
        performance: nil,
        part:        nil,
        chip:        nil
      }.update(options || {})
      _chips
      if s.nil?
        show_chips(options)
      elsif s.is_a? Hash
        options.update(s)
        show_chips(options)
      else
        options[:chip] = s
        show_chips(options)
      end
    end

    # Define and instantiate a Spec object
    def chip(name, description, selector = {}, options = {}, &block)
      # return chips(name, group) unless block_given?
      _chips
      name = name_audit(name)
      group = selector[:group]
      family = selector[:family]
      performance = selector[:performance]
      previous_parts = selector[:previous_parts]
      power = selector[:power]
      chip_holder = Chip.new(name, description, previous_parts, power, options)
      if has_chip?(name, group: group, family: family, performance: performance, creating_chip: true)
        fail "Chip already exists for chip: #{name}, group: #{group}, family: #{family} for object #{self}"
      end

      @_chips[group][family][performance][name] = chip_holder
    end

    # Returns Boolean based on whether the calling object has any defined specs
    # If the mode option is selected then the search is narrowed
    def has_chips?(options = {})
      _chips
      options = {
        group:         nil,
        family:        nil,
        performance:   nil,
        chip:          nil,
        creating_chip: false
      }.update(options)
      if @_chips.nil? || @_chips == {}
        false
      else
        !!show_chips(options)
      end
    end

    # Check if the current IP has a spec
    def has_chip?(s, options = {})
      _chips
      options = {
        group:         nil,
        family:        nil,
        performance:   nil,
        chip:          nil,
        creating_spec: false
      }.update(options)
      options[:chip] = s
      !!show_chips(options)
    end

    # Define and instantiate a Note object
    def note(id, type, feature)
      _notes
      @_notes[id][type] = RSS_Note.new(id, type, feature)
    end

    def doc(date, type, revision, description, options = {})
      _docs
      @_docs[type][revision] = Doc_Entry.new(date, type, revision, description, options)
    end

    def design(date, type, revision, description, options = {})
      _designs
      @_designs[type][revision] = Design_Entry.new(date, type, revision, description, options)
    end

    # Returns a Note object from the notes hash
    def notes(options = {})
      options = {
        id:   nil,
        type: nil
      }.update(options)
      notes_found = Hash.new do |h, k|
        h[k] = {}
      end
      _notes.filter(options[:id]).each do |id, hash|
        hash.filter(options[:type]).each do |type, note|
          notes_found[id][type] = note
        end
      end
      if notes_found.empty?
        nil
      elsif notes_found.size == 1
        notes_found.values.first.values.first
      else
        notes_found
      end
    end

    def docs(options = {})
      options = {
        type: nil,
        rev:  nil
      }.update(options)
      docs_to_be_shown = []
      filter_hash(_docs, options[:type]).each do |type, hash|
        filter_hash(hash, options[:rev]).each do |revision, hash_|
          docs_to_be_shown << hash_
        end
      end
      docs_to_be_shown
    end

    def designs(options = {})
      options = {
        type: nil,
        rev:  nil
      }.update(options)
      designs_to_be_shown = []
      filter_hash(_designs, options[:type]).each do |type, hash|
        filter_hash(hash, options[:rev]).each do |revision, hash_|
          designs_to_be_shown << hash_
        end
      end
      designs_to_be_shown
    end

    # Delete all specs
    def delete_all_chips
      @_chips = nil
    end

    # Delete all notes
    def delete_all_notes
      @_notes = nil
    end

    # Delete all doc
    def delete_all_docs
      @_docs = nil
    end

    def delete_all_designs
      @_designs = nil
    end

    private

    # rubocop:disable Lint/DuplicateMethods

    def _chips
      # 4D hash with group, family, and performance
      @_chips ||= Hash.new do |h, k|
        h[k] = Hash.new do |hh, kk|
          hh[kk] = Hash.new do |hhh, kkk|
            hhh[kkk] = {}
          end
        end
      end
    end

    # Two-dimensional hash with note id and type as the keys
    def _notes
      @_notes ||= Hash.new do |h, k|
        h[k] = {}
      end
    end

    # Document Type and Revision Number :: 2-D Hash
    def _docs
      @_docs ||= Hash.new do |h, k|
        h[k] = {}
      end
    end

    # Document Type and Revision Number :: 2-D Hash
    def _designs
      @_designs ||= Hash.new do |h, k|
        h[k] = {}
      end
    end
    # rubocop:enable Lint/DuplicateMethods

    # Return a hash based on the filter provided
    def filter_hash(hash, filter)
      fail 'Hash argument is not a Hash!' unless hash.is_a? Hash

      filtered_hash = {}
      select_logic = case filter
        when String then 'k[Regexp.new(filter)]'
        when (Integer || Float || Numeric) then "k[Regexp.new('#{filter}')]"
        when Regexp then 'k[filter]'
        when Symbol then
          'k == filter'
        when NilClass then true # Return all specs if a filter is set to nil (i.e. user doesn't care about this filter)
        else true
                     end
      filtered_hash = hash.select do |k, v|
        [TrueClass, FalseClass].include?(select_logic.class) ? select_logic : eval(select_logic)
      end
      filtered_hash
    end

    # Filters the 4D hash to find specs for all user visible API
    def show_chips(options = {})
      options = {
        group:             nil,
        family:            nil,
        performance:       nil,
        part:              nil,
        chips_to_be_shown: ChipArray.new,
        creating_chip:     false
      }.update(options)
      chips_to_be_shown = options[:chips_to_be_shown]
      filter_hash(_chips, options[:group]).each do |_group, hash|
        filter_hash(hash, options[:family]).each do |_family, hash_|
          filter_hash(hash_, options[:performance]).each do |_performance, hash__|
            filter_hash(hash__, options[:part]).each do |_part, chip|
              chips_to_be_shown << chip
            end
          end
        end
      end
      # If no specs were found must check the possibility another search
      # should be started with mode set to :local or :global
      if chips_to_be_shown.empty?
        # Don't want to re-call this method if the callee is trying to create a spec and just wants to know
        # if there is a spec with the exact same options
        if options[:creating_chip] == false
          # Doesn't make sense to recall the method however if the mode is already set to :global or :local
          options[:chips_to_be_shown] = chips_to_be_shown
          Origen.log.debug "re-calling show_chips with options #{options}"
          return show_chips(options)
        end
        Origen.log.debug "Returning no chips for options #{options}"
        nil
      elsif chips_to_be_shown.size == 1
        Origen.log.debug "returning one spec #{chips_to_be_shown.first.part_name}"
        chips_to_be_shown.first
      else
        Origen.log.debug "returning an array of specs during initial search: #{chips_to_be_shown}"
        chips_to_be_shown
      end
    end
  end
end
