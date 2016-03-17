module Origen
  module Specs
    class Spec
      autoload :Note, 'origen/specs/note'
      autoload :Exhibit, 'origen/specs/exhibit'
      include Checkers
      extend Checkers

      SpecAttribute = Struct.new(:name, :type, :required, :author, :description)

      Limit = Struct.new(:exp) do
        def value
          Origen::Specs::Spec.send(:evaluate_limit, exp)
        end
      end

      TYPES = Origen::Specs::SPEC_TYPES

      ATTRS = {
        ip_name:                    SpecAttribute.new(:ip_name, Symbol, true, :design, 'The parent IP object of the specification'),
        name:                       SpecAttribute.new(:name, Symbol, true, :design, 'Specification Name'),
        type:                       SpecAttribute.new(:type, Symbol, true, :design, "Specification Type, acceptable values: #{TYPES}"),
        sub_type:                   SpecAttribute.new(:sub_type, Symbol, true, :design, 'Specification sub-type (e.g. :max_operating_condition)'),
        mode:                       SpecAttribute.new(:mode, Symbol, true, :design, 'Specification mode, inherited from the owning parent object'),
        symbol:                     SpecAttribute.new(:symbol, String, false, :design, 'Specification symbol, can contain HTML'),
        description:                SpecAttribute.new(:description, String, false, :design, 'Specification description'),
        audience:                   SpecAttribute.new(:audience, Symbol, false, :design, 'Specification audience, acceptable values are :internal and :external'),
        min:                        SpecAttribute.new(:min, Limit, false, :design, 'Specification minimum limit. The limit expression is displayed, not a resolved value'),
        min_ovr:                    SpecAttribute.new(:min_ovr, Limit, false, :design, 'Specification minimum limit at SoC level.  The limit expression is displaye,d not a resolved value'),
        max:                        SpecAttribute.new(:max, Limit, false, :design, 'Specification maximum limit. The limit expression is displayed, not a resolved value'),
        max_ovr:                    SpecAttribute.new(:max_ovr, Limit, false, :design, 'Specification maximum limit at SoC level.  The limit expression is displaye,d not a resolved value'),
        typ:                        SpecAttribute.new(:typ, Limit, false, :design, 'Specification typical limit. The limit expression is displayed, not a resolved value'),
        typ_ovr:                    SpecAttribute.new(:typ_ovr, Limit, false, :design, 'Specification typical limit at SoC level.  The limit expression is displaye,d not a resolved value'),
        unit:                       SpecAttribute.new(:unit, String, false, :design, 'Specification unit of measure'),
        constraints:                SpecAttribute.new(:constraints, String, false, :design, "Single logical expression or a CSV list of logical expressions required for the spec to be valid (e.g. 'GVDD == 1.2V'"),
        limit_type:                 SpecAttribute.new(:limit_type, Symbol, false, :design, 'Auto-generated attribute based on analysis of the spec limits. Acceptable values are :single_sided and :double_sided'),
        notes:                      SpecAttribute.new(:notes, Hash, false, :design, 'Specification notes'),
        hidespec:                   SpecAttribute.new(:hidespec, [String, Array], false, :design, 'Add the ability to hide specs based off license plate'),
        disposition_required:       SpecAttribute.new(:disposition_required, TrueClass, false, :pde, 'Boolean representation of whether a specification needs a disposition based on silicon results or customer input'),
        priority:                   SpecAttribute.new(:priority, TrueClass, false, :pde, 'Integer value (1-4) to indicate which priority the cz for this spec will be:  1. Highest priority, for critical or historically risky specs   2. Medium priority, relatively low risk. Not required until all priority 1 specs have been handled  3. Lowest priority, very low risk, low performance specs  4. No plans to characterize'),
        target:                     SpecAttribute.new(:target, String, false, :pde, 'Specification target limit.  Not used for pass/fail results but for data analysis'),
        guardband:                  SpecAttribute.new(:guardband, Limit, false, :pde, 'Specification guardband limit'),
        testable:                   SpecAttribute.new(:testable, TrueClass, false, :pde, 'Boolean representation of whether a specification is testable'),
        tested_at_probe:            SpecAttribute.new(:tested_at_probe, TrueClass, false, :pde, 'Boolean representation of whether a specification is tested at probe'),
        tested_at_ft_hot:           SpecAttribute.new(:tested_at_ft_hot, TrueClass, false, :pde, 'Boolean representation of whether a specification is tested at final test hot temperature'),
        tested_at_ft_ext_hot:       SpecAttribute.new(:tested_at_ft_ext_hot, TrueClass, false, :pde, 'Boolean representation of whether a specification is tested at final test extended hot temperature'),
        tested_at_ft_cold:          SpecAttribute.new(:tested_at_ft_cold, TrueClass, false, :pde, 'Boolean representation of whether a specification is tested at final test cold temperature'),
        tested_at_ft_ext_cold:      SpecAttribute.new(:tested_at_ft_ext_cold, TrueClass, false, :pde, 'Boolean representation of whether a specification is tested at final test extended cold temperature'),
        tested_at_ft_room:          SpecAttribute.new(:tested_at_ft_room, TrueClass, false, :pde, 'Boolean representation of whether a specification is tested at final test room temperature'),
        guaranteed_by_prod_test:    SpecAttribute.new(:guaranteed_by_prod_test, TrueClass, false, :pde, 'Boolean representation of whether a specification is guaranteed by production test'),
        guaranteed_by_proxy_test:   SpecAttribute.new(:guaranteed_by_proxy_test, TrueClass, false, :pde, 'Boolean representation of whether a specification is guaranteed by production test via a proxy test such as BIST'),
        guaranteed_by_construction: SpecAttribute.new(:guaranteed_by_construction, TrueClass, false, :pde, 'Boolean representation of whether a specification is guaranteed by physical construction, design documentation required'),
        guaranteed_by_simulation:   SpecAttribute.new(:guaranteed_by_simulation, TrueClass, false, :pde, 'Boolean representation of whether a specification is tested guaranteed by simulation, design documentation required'),
        cz_on_ate:                  SpecAttribute.new(:cz_on_ate, TrueClass, false, :pde, 'Boolean representation of whether a specification is characterized on ATE'),
        cz_ate_sample_size:         SpecAttribute.new(:cz_ate_sample_size, Integer, false, :pde, 'Integer number representing the sample size of the split used for customer Cpk calculation as tested on ATE'),
        cz_ate_cpk:                 SpecAttribute.new(:cz_ate_cpk, Float, false, :pde, 'Float number representing the customer or representative Cpk of the specification as tested on ATE'),
        cz_on_bench:                SpecAttribute.new(:cz_on_bench, TrueClass, false, :pde, 'Boolean representation of whether a specification is characterized on a bench setup'),
        cz_bench_sample_size:       SpecAttribute.new(:cz_bench_sample_size, Integer, false, :pde, 'Integer number representing the sample size of the split used for customer Cpk calculation on a bench setup'),
        cz_bench_cpk:               SpecAttribute.new(:cz_bench_cpk, Float, false, :pde, 'Float number representing the customer or representative Cpk of the specification as tested on a bench setup'),
        cz_on_system:               SpecAttribute.new(:cz_on_system, TrueClass, false, :pde, 'Boolean representation of whether a specification is characterized in a system setup'),
        cz_system_sample_size:      SpecAttribute.new(:cz_system_sample_size, Integer, false, :pde, 'Integer number representing the sample size of the split used for customer Cpk calculation in a system'),
        cz_system_cpk:              SpecAttribute.new(:cz_system_cpk, Float, false, :pde, 'Float number representing the customer or representative Cpk of the specification as tested in a system')
      }

      ATTRS.each do |_id, spec_attr|
        class_eval("def #{spec_attr.name}(param=nil); param.nil?  ? @#{spec_attr.name} : (@#{spec_attr.name} = param); end")
      end

      # There are at least three attributes needed to define a unique spec.
      #   1) name (e.g. :vdd)
      #   2) type (e.g. :dc)  Possible values are [:dc, :ac, :temperature]
      #   3) mode (e.g. :global).  mode defaults to the current mode found for the parent object
      # A mode is defined as a device state that requires some sequence of actions to be enabled.
      # A type is a classification moniker that exists without any stimulus required.
      # Some specs require a fourth attribute sub_type to be uniquely defined.
      # For example, a global device level VDD specification would require four attributes to be unique.
      # Here is an example of two spec definitions for a VDD power supply
      #   name = :vdd, type: :dc, mode: :global, sub_type: typical_operating_conditions, typ = "1.0V +/- 30mV"
      #   name = :vdd, type: :dc, mode: :global, sub_type: maximum_operating_conditions, min = -0.3V, max = 1.8V
      # Whereas a typical DDR timing specification might only need three attributes to be unique
      #   name: :tddkhas, type: :ac, mode: ddr4dr2400, sub_type: nil

      def initialize(name, type, mode, owner_name, &block)
        @name = name_audit(name)
        fail 'Specification names must be of types Symbol or String and cannot start with a number' if @name.nil?
        @type = type
        @sub_type = nil # not necessary to be able to find a unique spec, but required for some specs
        @mode = mode
        @ip_name = owner_name
        @symbol = nil # Meant to be populated with HTML representing the way the spec name should look in a document
        @description = nil
        @min, @typ, @max, @target = nil, nil, nil, nil
        @min_ovr, @typ_ovr, @typ_ovr = nil, nil, nil
        @audience = nil
        @notes = {}
        @exhibits = {}
        @testable = nil
        @guardband = nil
        (block.arity < 1 ? (instance_eval(&block)) : block.call(self)) if block_given?
        fail "Spec type must be one of #{TYPES.join(', ')}" unless TYPES.include? type
        @min = Limit.new(@min)
        @max = Limit.new(@max)
        @typ = Limit.new(@typ)
        @min_ovr = Limit.new(@min_ovr)
        @max_ovr = Limit.new(@max_ovr)
        @typ_ovr = Limit.new(@typ_ovr)
        @guardband = Limit.new(@guardband)
        fail "Spec #{name} failed the limits audit!" unless limits_ok?
      end

      def inspect
        $dut.send(:specs_to_table_string, [self])
      rescue
        super
      end

      # Returns the trace_matrix name.  The Trace Matrix Name is composed of
      # * @name
      # * @type
      # * @subtype
      # * @mode
      def trace_matrix_name
        name_set = trace_matrix_name_choose
        ret_name = ''
        case name_set
        when 0
          ret_name = ''
        when 1
          ret_name = "#{@mode}"
        when 2
          ret_name = "#{@sub_type}"
        when 3
          ret_name = "#{@sub_type}_#{@mode}"
        when 4
          ret_name = "#{@type}"
        when 5
          ret_name = "#{@type}_#{@mode}"
        when 6
          ret_name = "#{@type}_#{@sub_type}"
        when 7
          ret_name = "#{@type}_#{@sub_type}_#{@mode}"
        when 8
          ret_name = "#{small_name}"
        when 9
          ret_name = "#{small_name}_#{@mode}"
        when 10
          ret_name = "#{small_name}_#{@sub_type}"
        when 11
          ret_name = "#{small_name}_#{@sub_type}_#{@mode}"
        when 12
          ret_name = "#{small_name}_#{@type}"
        when 13
          ret_name = "#{small_name}_#{@type}_#{@mode}"
        when 14
          ret_name = "#{small_name}_#{@type}_#{@sub_type}"
        when 15
          ret_name = "#{small_name}_#{@type}_#{@sub_type}_#{@mode}"
        else
          ret_name = 'Bad trace matrix code'
        end
        ret_name
      end

      # This will create the trace matrix name to be placed into a dita phrase element
      # End goal will be
      # {code:xml}
      #   <ph audience="internal">trace_matrix_name</ph>
      # {code}
      def trace_matrix_name_to_dita
        tmp_doc = Nokogiri::XML('<foo><bar /></foo>', nil, 'EUC-JP')

        tmp_node = Nokogiri::XML::Node.new('lines', tmp_doc)
        tmp_node1 = Nokogiri::XML::Node.new('i', tmp_doc)
        tmp_node.set_attribute('audience', 'trace-matrix-id')
        text_node1 = Nokogiri::XML::Text.new("[#{trace_matrix_name}]", tmp_node)
        tmp_node1 << text_node1
        tmp_node << tmp_node1
        tmp_node.at_xpath('.').to_xml
      end

      def method_missing(method, *args, &block)
        ivar = "@#{method.to_s.gsub('=', '')}"
        ivar_sym = ":#{ivar}"
        if method.to_s =~ /=$/
          define_singleton_method(method) do |val|
            instance_variable_set(ivar, val)
          end
        elsif instance_variables.include? ivar_sym
          instance_variable_get(ivar)
        else
          define_singleton_method(method) do
            instance_variable_get(ivar)
          end
        end
        send(method, *args, &block)
      end

      # Do a 'diff' from the current spec (self) and the compare spec
      # Returns a hash with attribute as key and an array of the
      # attribute values that differed
      def diff(compare_spec)
        diff_results = Hash.new do |h, k|
          h[k] = []
        end
        # Loop through self's isntance variables first
        instance_variables.each do |ivar|
          ivar_sym = ivar.to_s.gsub('@', '').to_sym
          next if ivar_sym == :notes # temporarily disable until notes diff method written
          ivar_str = ivar.to_s.gsub('@', '')
          if compare_spec.respond_to? ivar_sym
            # Check if the instance variable is a Limit and if so then find
            # all instance_variables and diff them as well
            if instance_variable_get(ivar).class == Origen::Specs::Spec::Limit
              limit_diff_results = diff_limits(instance_variable_get(ivar), compare_spec.instance_variable_get(ivar))
              # Extract the limit diff pairs and merge with updated keys with the diff_results hash
              limit_diff_results.each do |k, v|
                limit_diff_key = "#{ivar_str}_#{k}".to_sym
                diff_results[limit_diff_key] = v
              end
            else
              unless instance_variable_get(ivar) == compare_spec.instance_variable_get(ivar)
                diff_results[ivar_sym] = [instance_variable_get(ivar), compare_spec.instance_variable_get(ivar)]
                Origen.log.debug "Found spec difference for instance variable #{ivar} for #{self} and #{compare_spec}"
              end
            end
          else
            # The compare spec doesn't have the current instance variable
            # so log a difference
            if instance_variable_get(ivar).class == Origen::Specs::Spec::Limit
              limit_diff_results = diff_limits(instance_variable_get(ivar), compare_spec.instance_variable_get(ivar))
              # Extract the limit diff pairs and merge with updated keys with the diff_results hash
              limit_diff_results.each do |k, v|
                limit_diff_key = "#{ivar_str}_#{k}".to_sym
                diff_results[limit_diff_key] = v
              end
            else
              Origen.log.debug "Instance variable #{ivar} exists for #{self} and does not for #{compare_spec}"
              diff_results[ivar_sym] = [instance_variable_get(ivar), '']
            end
          end
        end
        # Loop through unique instance variables for compare_spec
        diff_results
      end

      # Monkey patch of hash/array include? method needed because
      # Origen::Specs#specs can return a single Spec instance or an Array of Specs
      def include?(s)
        s == @name ? true : false
      end

      # Add a specification note
      def add_note(id, options = {})
        options = {
          type: :spec
        }.update(options)
        # Create the Note instance and add to the notes attribute
        @notes[id] = Origen::Specs::Note.new(id, options[:type], options)
      end

      # Returns a Note object from the notes hash
      def notes(id = nil)
        return nil if @notes.nil?
        @notes.filter(id)
      end

      # Returns the number of notes as an Integer
      def note_count
        @notes.size
      end

      private

      def small_name
        if @name.to_s[0..@ip_name.to_s.length].include? @ip_name.to_s
          ret_name = @name.to_s[@ip_name.to_s.length + 1..-1]
        else
          ret_name = @name.to_s
        end
        ret_name = ret_name.partition('-').last if ret_name.include? '-'
        ret_name
      end

      # This assumes the limit objects are Structs
      def diff_limits(limit_one, limit_two = nil)
        diff_results = Hash.new do |h, k|
          h[k] = []
        end
        # Only need to loop through limit one ivars because the Limit class cannot
        # be changed in 3rd party files like the Spec class can be
        limit_one.members.each do |m|
          if limit_two.respond_to? m
            unless limit_one.send(m) == limit_two.send(m)
              diff_results[m] = [limit_one.send(m), limit_two.send(m)]
              Origen.log.debug "Found limit difference for member #{m} for #{limit_one} and #{limit_two}"
            end
          else
            # Limit two doesn't have the current instance variable or was not provided
            # as an argument so log a difference
            Origen.log.debug "Member #{m} exists for #{limit_one} and does not for #{limit_two}"
            diff_results[m] = [limit_one.send(m), '']
          end
        end
        diff_results
      end

      def trace_matrix_name_choose
        name_set = 0
        name_set = 8 unless @name.nil?
        name_set += 4 unless @type.nil?
        name_set += 2 unless @sub_type.nil?
        unless @mode.nil?
          unless  (@mode.to_s.include? 'local') || (@mode.to_s.include? 'global')
            name_set += 1
          end
        end
        name_set
      end
    end
  end
end
