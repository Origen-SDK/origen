module Origen
  module Specs
    autoload :Spec, 'origen/specs/spec'
    autoload :Note, 'origen/specs/note'
    autoload :Exhibit, 'origen/specs/exhibit'
    autoload :Doc_Resource, 'origen/specs/doc_resource.rb'
    autoload :Override, 'origen/specs/override.rb'
    autoload :Power_Supply, 'origen/specs/power_supply.rb'
    autoload :Mode_Select, 'origen/specs/mode_select.rb'
    autoload :Version_History, 'origen/specs/version_history.rb'
    autoload :Creation_Info, 'origen/specs/creation_info.rb'
    autoload :Spec_Features, 'origen/specs/spec_features.rb'
    require 'origen/specs/checkers'
    include Checkers

    attr_accessor :_specs, :_notes, :_exhibits, :_doc_resources, :_overrides, :_power_supplies, :_mode_selects, :_version_history, :_creation_info, :_spec_features

    # Detailed description for the ip block
    attr_accessor :description

    # Added :impedance and :power to the spec types
    SPEC_TYPES = [:dc, :ac, :temperature, :supply, :impedance, :power]

    NOTE_TYPES = [:spec, :doc, :mode, :feature, :sighting]

    FEATURE_TYPES = [:intro, :feature, :subfeature]

    SpecTableAttr = Struct.new(:table_text, :show, :padding)

    # A regular Array but print specs to the console via their ID for brevity and
    # consistency with other APIs (e.g. $dut.regs  # => [:reg1, :reg2])
    class SpecArray < Array
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
    def specs(s = nil, options = {})
      options = {
        type:          nil,
        sub_type:      nil,
        mode:          current_mode.nil? ? nil : current_mode.name,
        spec:          nil,
        creating_spec: false
      }.update(options || {})
      _specs
      if s.nil?
        return show_specs(options)
      elsif s.is_a? Hash
        # no spec was passed but some option was passed
        options.update(s)
        return show_specs(options)
      else
        # a spec was passed
        options[:spec] = s
        return show_specs(options)
      end
    end

    # Define and instantiate a Spec object
    def spec(name, type = nil, mode = nil, &block)
      return specs(name, type) unless block_given?
      fail 'A type argument is required when defining a spec!' unless type
      _specs
      name = name_audit(name)
      fail 'Specification names must be of SPEC_TYPES Symbol or String and cannot start with a number' if name.nil?
      fail "Spec type must be one of #{SPEC_TYPES.join(', ')}" unless SPEC_TYPES.include? type
      type = type
      mode = get_mode if mode.nil?
      owner_name = ''
      if self.respond_to?(:name) && send(:name)
        owner_name = self.name.to_s.downcase.to_sym
      elsif self == Origen.top_level
        owner_name = self.class.to_s.split('::').last.downcase.to_sym
      else
        owner_name = self.class.to_s.split('::').last.downcase.to_sym
      end
      spec_placeholder = Spec
                         .new(name, type, mode, owner_name, &block)
      # Check if the spec already exists
      if has_spec?(name, type: type, mode: mode, sub_type: spec_placeholder.sub_type, creating_spec: true)
        # Spec already exists.  Go ahead flag error and drop processing.
        # This is a fatal error.
        fail "Spec already exists for name: #{name}, type: #{type}, mode: #{mode} for object #{self}"
      end
      @_specs[name][mode][type][spec_placeholder.sub_type] = spec_placeholder
    end

    # Returns Boolean based on whether the calling object has any defined specs
    # If the mode option is selected then the search is narrowed
    def has_specs?(options = {})
      _specs
      options = {
        type:          nil,
        sub_type:      nil,
        mode:          current_mode.nil? ? nil : current_mode.name,
        spec:          nil,
        creating_spec: false
      }.update(options)
      if @_specs.nil? || @_specs == {}
        return false
      else
        return !!show_specs(options)
      end
    end

    # Returns the modes for this block
    def get_modes
      @_modes
    end

    # Check if the current IP has a spec
    def has_spec?(s, options = {})
      _specs
      options = {
        type:          nil,
        sub_type:      nil,
        mode:          current_mode.nil? ? nil : current_mode.name,
        spec:          nil,
        creating_spec: false
      }.update(options)
      options[:spec] = s
      !!show_specs(options)
    end

    # Adds a new feature to the block
    def spec_feature(id, attrs, device, text, internal_comment)
      # Welguisz:  No idea why this is here, but keeping it here because it follows other blocks
      _spec_features
      # Create a new feature and place it in the features 2-D Hash
      @_spec_features[id][device] = Spec_Features.new(id, attrs, device, text, internal_comment)
    end

    # Define and instantiate a Note object
    def note(id, type, options = {})
      # Welguisz:  No idea why this is here, but keeping it here because it follows other blocks
      _notes
      # Create a new note and place it in the notes 2-D Hash
      @_notes[id][type] = Note.new(id, type, options)
    end

    def exhibit(id, type, overrides = {}, options = {})
      # Welguisz:  No idea why this is here, but keeping it here because it follows other blocks
      _exhibits
      # Create a new Exhibit and place it in the exhibits 3-D Hash
      @_exhibits[options[:block_id]][id][type] = Exhibit.new(id, type, overrides, options)
    end

    def doc_resource(selector = {}, table_title = {}, text = {}, options = {})
      # Welguisz:  No idea why this is here, but keeping it here because it follows other blocks
      _doc_resources
      mode = selector[:mode]
      type = selector[:type]
      sub_type = selector[:sub_type]
      audience = selector[:audience]
      # Create a new Document Resource and place it in the Doc Resources 4-D Hash
      @_doc_resources[mode][type][sub_type][audience] = Doc_Resource.new(selector, table_title, text, options)
    end

    def version_history(date, author, changes)
      # Welguisz:  No idea why this is here, but keeping it here because it follows other blocks
      _version_history
      # Create a new Version History and place it in the version history 2-D Hash
      tmp_ver_history = Version_History.new(date, author, changes)
      @_version_history[date][author] = tmp_ver_history
    end

    def override(block_options = {}, find_spec = {}, values = {}, options = {})
      # Welguisz:  No idea why this is here, but keeping it here because it follows other blocks
      _overrides
      block = block_options[:block]
      spec_ref = find_spec[:spec_id]
      mode_ref = find_spec[:mode_ref]
      sub_type = find_spec[:sub_type]
      audience = find_spec[:audience]
      # Create a new Override and place it in the overrides 5-D Hash
      @_overrides[block][spec_ref][mode_ref][sub_type][audience] = Override.new(block_options, find_spec, values, options)
    end

    def power_supply(gen, act)
      # Welguisz:  No idea why this is here, but keeping it here because it follows other blocks
      _power_supplies
      # Create a new Power Supply and place it in the power supplies 2-D Hash
      @_power_supplies[gen][act] = Power_Supply.new(gen, act)
    end

    def mode_select(block_information, mode_usage, power_information)
      # Welguisz:  No idea why this is here, but keeping it here because it follows other blocks
      _mode_selects
      # See if the mode will be used.  If so, create a new Mode Select and place it in mode_selects 2-D Hash
      if block_information[:usage]
        @_mode_selects[block_information[:name]][mode_usage[:mode]] = Mode_Select.new(block_information, mode_usage, power_information)
      end
    end

    def creation_info(author, date, version, src_info = {}, tool_info = {})
      # Create a new Information Information.  Should only be one.
      @_creation_info = Creation_Info.new(author, date, version, src_info, tool_info)
    end

    def get_creation_info
      @_creation_info
    end

    # Returns a Note object from the notes hash
    def notes(options = {})
      # Create a default 2 item hash and update if options is supplied
      options = {
        id:   nil,
        type: nil
      }.update(options)
      # Empty 2-D Hash to be used for notes found based on id and type
      notes_found = Hash.new do |h, k|
        # h is the id portion of the hash
        # k is the type portion of the hash
        h[k] = {}
      end
      # Filter @notes based off of the id
      @_notes.filter(options[:id]).each do |id, hash|
        # Filter hash based off of the type
        hash.filter(options[:type]).each do |type, note|
          # Store the note into note_found
          notes_found[id][type] = note
        end
      end
      if notes_found.empty?
        return nil
      elsif notes_found.size == 1
        notes_found.values.first.values.first
      else
        return notes_found
      end
    end

    def spec_features(options = {})
      options = {
        id:     nil,
        device: nil
      }.update(options)
      return @_spec_features if options[:id].nil? && options[:device].nil?
      features_found = Hash.new do |h, k|
        h[k] = {}
      end
      @_spec_features.filter(options[:id]).each do |id, hash|
        hash.filter(options[:device]).each do |device, feat|
          features_found[id][device] = feat
        end
      end
      if features_found.empty?
        return nil
      elsif features_found.size == 1
        features_found.values.first.values.first
      else
        return features_found
      end
    end

    def exhibits(options = {})
      options = {
        block: nil,
        id:    nil,
        type:  nil
      }.update(options)
      ex_found = Hash.new do |h, k|
        h[k] = Hash.new do |hh, kk|
          hh[kk] = {}
        end
      end
      filter_hash(_exhibits, options[:block]).each do |_block, hash|
        filter_hash(hash, options[:id]).each do |_id, hash_|
          filter_hash(hash_, options[:type]).each do |_type, exh|
            ex_found[_block][_id][_type] = exh
          end
        end
      end
      if ex_found.empty?
        return nil
      else
        return ex_found
      end
    end

    def doc_resources(options = {})
      options = {
        mode:     nil,
        type:     nil,
        sub_type: nil,
        audience: nil
      }.update(options)
      dr_found = Hash.new do |h, k|
        h[k] = Hash.new do |hh, kk|
          hh[kk] = Hash.new do |hhh, kkk|
            hhh[kkk] = {}
          end
        end
      end
      filter_hash(_doc_resources, options[:mode]).each do |_mode, hash|
        filter_hash(hash, options[:type]).each do |_type, hash_|
          filter_hash(hash_, options[:sub_type]).each do |_sub_type, hash__|
            filter_hash(hash__, options[:audience]).each do |_audience, spec|
              dr_found[_mode][_type][_sub_type][_audience] = spec
            end
          end
        end
      end
      if dr_found.empty?
        return nil
      else
        return dr_found
      end
    end

    def overrides(options = {})
      options = {
        block:    nil,
        spec_ref: nil,
        mode_ref: nil,
        sub_type: nil,
        audience: nil
      }.update(options)
      overrides_found = Hash.new do |h, k|
        h[k] = Hash.new do |hh, kk|
          hh[kk] = Hash.new do |hhh, kkk|
            hhh[kkk] = Hash.new do |hhhh, kkkk|
              hhhh[kkkk] = {}
            end
          end
        end
      end
      filter_hash(_overrides, options[:block]).each do |_block, hash|
        filter_hash(hash, options[:spec_ref]).each do |_spec_ref, hash_|
          filter_hash(hash_, options[:mode_ref]).each do |_mode_ref, hash__|
            filter_hash(hash__, options[:sub_type]).each do |_sub_type, hash___|
              filter_hash(hash___, options[:audience]).each do |_audience, override|
                overrides_found[_block][_spec_ref][_mode_ref][_sub_type][_audience] = override
              end
            end
          end
        end
      end
      if overrides_found.empty?
        return nil
      else
        return overrides_found
      end
    end

    def mode_selects(options = {})
      options = {
        block: nil,
        mode:  nil
      }.update(options)
      modes_found = Hash.new do|h, k|
        h[k] = {}
      end
      _mode_selects.filter(options[:block]).each do |block, hash|
        hash.filter(options[:mode]).each do |mode, sel|
          modes_found[block][mode] = sel
        end
      end
      if modes_found.empty?
        return nil
      else
        return modes_found
      end
    end

    def power_supplies(options = {})
      options = {
        gen: nil,
        act: nil
      }.update(options)
      ps_found = Hash.new do|h, k|
        h[k] = {}
      end
      _power_supplies.filter(options[:gen]).each do |gen, hash|
        hash.filter(options[:act]).each do |act, sel|
          ps_found[gen][act] = sel
        end
      end
      if ps_found.empty?
        return nil
      else
        return ps_found
      end
    end

    def versions
      @_version_history
    end

    def info
      @_creation_info
    end

    # Delete all specs
    def delete_all_specs
      @_specs = nil
    end

    # Delete all notes
    def delete_all_notes
      @_notes = nil
    end

    # Delete all exhibits
    def delete_all_exhibits
      @_exhibits = nil
    end

    def delete_all_doc_resources
      @_doc_resources = nil
    end

    def delete_all_overrides
      @_overrides = nil
    end

    def delete_all_power_supplies
      @_power_supplies = nil
    end

    def delete_all_version_history
      @_version_history = nil
    end

    def delete_all_mode_selects
      @_mode_selects = nil
    end

    def delete_creation_info
      @_creation_info = nil
    end

    def delete_spec_features
      @_spec_features = nil
    end

    private

    def _specs
      # 4D hash with name, type, mode, and sub_type as keys
      @_specs ||= Hash.new do |h, k|
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

    def _spec_features
      @_spec_features ||= Hash.new do |h, k|
        h[k] = {}
      end
    end

    def _exhibits
      @_exhibits ||= Hash.new do |h, k|
        h[k] = Hash.new do |hh, kk|
          hh[kk] = {}
        end
      end
    end

    def _doc_resources
      @_doc_resources ||= Hash.new do |h, k|
        h[k] = Hash.new do |hh, kk|
          hh[kk] = Hash.new do |hhh, kkk|
            hhh[kkk] = {}
          end
        end
      end
    end

    def _overrides
      @_overrides ||= Hash.new do |h, k|
        h[k] = Hash.new do |hh, kk|
          hh[kk] = Hash.new do |hhh, kkk|
            hhh[kkk] = Hash.new do |hhhh, kkkk|
              hhhh[kkkk] = {}
            end
          end
        end
      end
    end

    def _power_supplies
      @_power_supplies ||= Hash.new do |h, k|
        h[k] = {}
      end
    end

    def _mode_selects
      @_mode_selects ||= Hash.new do |h, k|
        h[k] = {}
      end
    end

    def _version_history
      @_version_history ||= Hash.new do |h, k|
        h[k] = {}
      end
    end

    def _creation_info
      @_creation_info = nil
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

    # Filters the 4D hash to find specs for all user visible API
    def show_specs(options = {})
      options = {
        mode:              nil,
        spec:              nil,
        type:              nil,
        sub_type:          nil,
        specs_to_be_shown: SpecArray.new,
        owner:             nil,
        creating_spec:     false
      }.update(options)
      specs_to_be_shown = options[:specs_to_be_shown]
      filter_hash(_specs, options[:spec]).each do |_spec, hash|
        filter_hash(hash, options[:mode]).each do |_mode, hash_|
          filter_hash(hash_, options[:type]).each do |_type, hash__|
            filter_hash(hash__, options[:sub_type]).each do |_sub_type, spec|
              specs_to_be_shown << spec
            end
          end
        end
      end
      # If no specs were found must check the possibility another search
      # should be started with mode set to :local or :global
      if specs_to_be_shown.empty?
        # Don't want to re-call this method if the callee is trying to create a spec and just wants to know
        # if there is a spec with the exact same options
        if options[:creating_spec] == false
          # Doesn't make sense to recall the method however if the mode is already set to :global or :local
          unless [:global, :local, nil].include?(options[:mode])
            # Need to check if there are :global or :local specs that match the filter(s) as well
            if self == Origen.top_level
              options[:mode] = :global
            else
              options[:mode] = :local
            end
            options[:specs_to_be_shown] = specs_to_be_shown
            Origen.log.debug "re-calling show_specs with options #{options}"
            return show_specs(options)
          end
        end
        Origen.log.debug "Returning no specs for options #{options}"
        return nil
      elsif specs_to_be_shown.size == 1
        print_to_console(specs_to_be_shown) if options[:verbose] == true
        Origen.log.debug "returning one spec #{specs_to_be_shown.first.name}"
        return specs_to_be_shown.first
      else
        Origen.log.debug "returning an array of specs during initial search: #{specs_to_be_shown}"
        return specs_to_be_shown
      end
    end

    # Method to print a spec table to the console
    def specs_to_table_string(specs_to_be_shown)
      whitespace_padding = 3
      table = []
      attrs_to_be_shown = {
        name:        SpecTableAttr.new('Name',      true,  'Name'.length + whitespace_padding),
        symbol:      SpecTableAttr.new('Symbol',    false, 'Symbol'.length + whitespace_padding),
        mode:        SpecTableAttr.new('Mode',      true,  'Mode'.length + whitespace_padding),
        type:        SpecTableAttr.new('Type',      true,  'Type'.length + whitespace_padding),
        sub_type:    SpecTableAttr.new('Sub-Type',  false, 'Sub-Type'.length + whitespace_padding),
        # spec SpecTableAttribute :description is called parameter in the spec table output to match historical docs
        description: SpecTableAttr.new('Parameter', false, 'Parameter'.length + whitespace_padding),
        min:         SpecTableAttr.new('Min',       false, 'Min'.length + whitespace_padding),
        typ:         SpecTableAttr.new('Typ',       false, 'Typ'.length + whitespace_padding),
        max:         SpecTableAttr.new('Max',       false, 'Max'.length + whitespace_padding),
        unit:        SpecTableAttr.new('Unit',      false, 'Unit'.length + whitespace_padding),
        audience:    SpecTableAttr.new('Audience',  false, 'Audience'.length + whitespace_padding)
        # notes:       SpecTableAttr.new('Notes',     false, 'Notes'.length + whitespace_padding)
      }
      # Calculate the padding needed in the spec table for the longest attr of all specs
      specs_to_be_shown.each do |spec|
        attrs_to_be_shown.each do |attr_name, attr_struct|
          unless spec.send(attr_name).nil?
            if spec.send(attr_name).class == Origen::Specs::Spec::Limit
              next if spec.send(attr_name).value.nil?
              current_padding = spec.send(attr_name).value.to_s.length + whitespace_padding
            else
              current_padding = spec.send(attr_name).to_s.length + whitespace_padding
            end
            attr_struct.padding = current_padding if attr_struct.padding < current_padding
            attr_struct.show = true # We found real data for this attr on at least one spec so show it in the spec table
          end
        end
      end
      # Now that each spec attribute padding construct the spec table header
      header = ''
      attrs_to_be_shown.each do |_attr_name, attr_struct|
        next if attr_struct.show == false
        header += "| #{attr_struct.table_text}".ljust(attr_struct.padding)
      end
      header += '|'
      ip_header = "| IP: #{specs_to_be_shown.first.ip_name} ".ljust(header.length - 1)
      ip_header += '|'
      table << '=' * header.length
      table << ip_header
      table << '=' * header.length
      table << header
      table << '-' * header.length
      # Create the data lines in the spec table
      specs_to_be_shown.each do |spec|
        data = ''
        attrs_to_be_shown.each do |attr_name, attr_struct|
          next if attr_struct.show == false
          if spec.send(attr_name).class == Origen::Specs::Spec::Limit
            data += "| #{spec.send(attr_name).value}".ljust(attr_struct.padding)
          else
            data += "| #{spec.send(attr_name)}".ljust(attr_struct.padding)
          end
        end
        table << data += '|'
      end
      table << '-' * header.length
      table.flatten.join("\n")
    end
  end
end
