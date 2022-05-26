module Origen
  module Chips
    class Chip
      # Part Name for the SoC, usually this will be the ID
      attr_accessor :part_name

      # Description for the Part, will be used as part of the RSS feed
      attr_accessor :description

      # Previous Roadmap Parts.  This will allow for a backwards viewable list so that
      # previous parts can have an upgrade path
      attr_accessor :previous_parts

      # Power Number
      attr_accessor :power

      # L2 Ram Size
      attr_accessor :l2_ram

      # L3 Ram Size
      attr_accessor :l3_ram

      # Package for the Part
      attr_accessor :package_type

      # Speed for the Cores
      attr_accessor :core_speed

      attr_accessor :_designs, :_docs, :_notes

      def initialize(part_name, description, previous_parts, power, options = {})
        @part_name = part_name
        @description = description
        @previous_parts = previous_parts
        @power = power
        @l2_ram = options[:l2_ram]
        @l3_ram = options[:l3_ram]
        @package_type = options[:package_type]
        @core_speed = options[:core_speed]
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
          when (Fixnum || Integer || Float || Numeric) then "k[Regexp.new('#{filter}')]"
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
    end
  end
end
