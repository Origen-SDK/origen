module RGen
  module Tester
    class J750
      module Generator
        class TestInstance
          attr_accessor :type, :index, :version, :append_version

          attrs = %w(
            test_name proc_type proc_name proc_called_as dc_category
            dc_selector ac_category ac_selector
            time_sets edge_sets pin_levels overlay
          )

          80.times do |i|
            attrs << "arg#{i}"
          end
          attrs << 'comment'

          ATTRS = attrs

          ALIASES = {
            name:             :test_name,
            time_set:         :time_sets,
            timeset:          :time_sets,
            timesets:         :time_sets,

            other:            {
            },

            empty:            {
              start_func:           :arg0,
              start_of_body_f:      :arg0,
              pre_pat_func:         :arg1,
              pre_pat_f:            :arg1,
              pre_test_func:        :arg2,
              pre_test_f:           :arg2,
              post_test_func:       :arg3,
              post_test_f:          :arg3,
              post_pat_func:        :arg4,
              post_pat_f:           :arg4,
              end_func:             :arg5,
              end_of_body_f:        :arg5,
              start_func_args:      :arg6,
              start_of_body_f_args: :arg6,
              pre_pat_func_args:    :arg7,
              pre_pat_f_args:       :arg7,
              pre_test_func_args:   :arg8,
              pre_test_f_args:      :arg8,
              post_test_func_args:  :arg9,
              post_test_f_args:     :arg9,
              post_pat_func_args:   :arg10,
              post_pat_f_args:      :arg10,
              end_func_args:        :arg11,
              end_of_body_f_args:   :arg11,
              utility_pins_1:       :arg12,
              utility_pins_0:       :arg13,
              init_lo:              :arg14,
              start_lo:             :arg14,
              init_hi:              :arg15,
              start_hi:             :arg15,
              init_hiz:             :arg16,
              start_hiz:            :arg16,
              float_pins:           :arg17
            },

            # Functional test instances
            functional:       {
              pattern:              :arg0,
              patterns:             :arg0,
              start_func:           :arg1,
              start_of_body_f:      :arg1,
              pre_pat_func:         :arg2,
              pre_pat_f:            :arg2,
              pre_test_func:        :arg3,
              pre_test_f:           :arg3,
              post_test_func:       :arg4,
              post_test_f:          :arg4,
              post_pat_func:        :arg5,
              post_pat_f:           :arg5,
              end_func:             :arg6,
              end_of_body_f:        :arg6,
              set_pass_fail:        :arg7,
              init_lo:              :arg8,
              start_lo:             :arg8,
              init_hi:              :arg9,
              start_hi:             :arg9,
              init_hiz:             :arg10,
              start_hiz:            :arg10,
              float_pins:           :arg11,
              start_func_args:      :arg13,
              start_of_body_f_args: :arg13,
              pre_pat_func_args:    :arg14,
              pre_pat_f_args:       :arg14,
              pre_test_func_args:   :arg15,
              pre_test_f_args:      :arg15,
              post_test_func_args:  :arg16,
              post_test_f_args:     :arg16,
              post_pat_func_args:   :arg17,
              post_pat_f_args:      :arg17,
              end_func_args:        :arg18,
              end_of_body_f_args:   :arg18,
              wait_flags:           :arg21,
              wait_time:            :arg22,
              pat_flag_func:        :arg23,
              pat_flag_f:           :arg23,
              PatFlagF:             :arg23,
              pat_flag_func_args:   :arg24,
              pat_flag_f_args:      :arg24,
              relay_mode:           :arg25,
              threading:            :arg26,
              match_all_sites:      :arg27,
              capture_mode:         :arg30,
              capture_what:         :arg31,
              capture_memory:       :arg32,
              capture_size:         :arg33,
              datalog_mode:         :arg34,
              data_type:            :arg35
            },

            board_pmu:        {
              hsp_start:            :arg0,
              start_func:           :arg1,
              start_of_body_f:      :arg1,
              pre_pat_func:         :arg2,
              pre_pat_f:            :arg2,
              pre_test_func:        :arg3,
              pre_test_f:           :arg3,
              post_test_func:       :arg4,
              post_test_f:          :arg4,
              post_pat_func:        :arg5,
              post_pat_f:           :arg5,
              end_func:             :arg6,
              end_of_body_f:        :arg6,
              precond_pat:          :arg7,
              hold_state_pat:       :arg8,
              holdstate_pat:        :arg8,
              pattern:              :arg8,
              pcp_stop:             :arg9,
              wait_flags:           :arg10,
              start_lo:             :arg11,
              init_lo:              :arg11,
              start_hi:             :arg12,
              init_hi:              :arg12,
              start_hiz:            :arg13,
              init_hiz:             :arg13,
              float_pins:           :arg14,
              pinlist:              :arg15,
              pin:                  :arg15,
              pin_list:             :arg15,
              measure_mode:         :arg16,
              irange:               :arg17,
              clamp:                :arg18,
              vrange:               :arg19,
              sampling_time:        :arg20,
              samples:              :arg21,
              settling_time:        :arg22,
              hi_lo_lim_valid:      :arg23,
              hi_lo_limit_valid:    :arg23,
              hi_limit:             :arg24,
              lo_limit:             :arg25,
              force_cond_1:         :arg26,
              force_cond:           :arg26,
              force_condition:      :arg26,
              force_cond_2:         :arg27,
              gang_pins_tested:     :arg28,
              relay_mode:           :arg29,
              wait_time_out:        :arg30,
              start_func_args:      :arg31,
              start_of_body_f_args: :arg31,
              pre_pat_func_args:    :arg32,
              pre_pat_f_args:       :arg32,
              pre_test_func_args:   :arg33,
              pre_test_f_args:      :arg33,
              post_test_func_args:  :arg34,
              post_test_f_args:     :arg34,
              post_pat_func_args:   :arg35,
              post_pat_f_args:      :arg35,
              end_func_args:        :arg36,
              end_of_body_f_args:   :arg36,
              pcp_start:            :arg37,
              pcp_check_pg:         :arg38,
              hsp_stop:             :arg39,
              hsp_check_pg:         :arg40,
              resume_pat:           :arg41,
              utility_pins_1:       :arg42,
              utility_pins_0:       :arg43,
              pre_charge_enable:    :arg44,
              pre_charge:           :arg45,
              threading:            :arg46
            },

            pin_pmu:          {
              hsp_start:            :arg0,
              start_func:           :arg1,
              start_of_body_f:      :arg1,
              pre_pat_func:         :arg2,
              pre_pat_f:            :arg2,
              pre_test_func:        :arg3,
              pre_test_f:           :arg3,
              post_test_func:       :arg4,
              post_test_f:          :arg4,
              post_pat_func:        :arg5,
              post_pat_f:           :arg5,
              end_func:             :arg6,
              end_of_body_f:        :arg6,
              precond_pat:          :arg7,
              hold_state_pat:       :arg8,
              holdstate_pat:        :arg8,
              pattern:              :arg8,
              pcp_stop:             :arg9,
              wait_flags:           :arg10,
              start_lo:             :arg11,
              init_lo:              :arg11,
              start_hi:             :arg12,
              init_hi:              :arg12,
              start_hiz:            :arg13,
              init_hiz:             :arg13,
              float_pins:           :arg14,
              pinlist:              :arg15,
              pin:                  :arg15,
              pin_list:             :arg15,
              measure_mode:         :arg16,
              irange:               :arg17,
              settling_time:        :arg18,
              hi_lo_lim_valid:      :arg19,
              hi_lo_limit_valid:    :arg19,
              hi_limit:             :arg20,
              lo_limit:             :arg21,
              force_cond_1:         :arg22,
              force_cond:           :arg22,
              force_condition:      :arg22,
              force_cond_2:         :arg23,
              fload:                :arg24,
              relay_mode:           :arg25,
              wait_time_out:        :arg26,
              start_func_args:      :arg27,
              start_of_body_f_args: :arg27,
              pre_pat_func_args:    :arg28,
              pre_pat_f_args:       :arg28,
              pre_test_func_args:   :arg29,
              pre_test_f_args:      :arg29,
              post_test_func_args:  :arg30,
              post_test_f_args:     :arg30,
              post_pat_func_args:   :arg31,
              post_pat_f_args:      :arg31,
              end_func_args:        :arg32,
              end_of_body_f_args:   :arg32,
              pcp_start:            :arg33,
              pcp_check_pg:         :arg34,
              hsp_stop:             :arg35,
              hsp_check_pg:         :arg36,
              sampling_time:        :arg37,
              samples:              :arg38,
              resume_pat:           :arg39,
              vcl:                  :arg40,
              vch:                  :arg41,
              utility_pins_1:       :arg42,
              utility_pins_0:       :arg43,
              pre_charge_enable:    :arg44,
              pre_charge:           :arg45,
              threading:            :arg46
            },

            apmu_powersupply: {
              precond_pat:              :arg0,
              pre_cond_pat:             :arg0,
              start_func:               :arg1,
              start_of_body_f:          :arg1,
              pre_pat_func:             :arg2,
              pre_pat_f:                :arg2,
              pre_test_func:            :arg3,
              pre_test_f:               :arg3,
              post_test_func:           :arg4,
              post_test_f:              :arg4,
              post_pat_func:            :arg5,
              post_pat_f:               :arg5,
              end_func:                 :arg6,
              end_of_body_f:            :arg6,
              hold_state_pat:           :arg7,
              holdstate_pat:            :arg7,
              wait_flags:               :arg8,
              wait_time_out:            :arg9,
              start_lo:                 :arg10,
              start_init_lo:            :arg10,
              init_lo:                  :arg10,
              start_hi:                 :arg11,
              start_init_hi:            :arg11,
              init_hi:                  :arg11,
              start_hiz:                :arg12,
              start_init_hiz:           :arg12,
              init_hiz:                 :arg12,
              float_pins:               :arg13,
              irange:                   :arg14,
              sampling_time:            :arg15,
              samples:                  :arg16,
              settling_time:            :arg17,
              hi_lo_lim_valid:          :arg18,
              hi_lo_limit_valid:        :arg18,
              hi_limit:                 :arg19,
              lo_limit:                 :arg20,
              force_cond_1:             :arg21,
              force_cond:               :arg21,
              force_condition:          :arg21,
              force_condition_1:        :arg21,
              force_cond_2:             :arg22,
              force_condition_2:        :arg22,
              power_pins:               :arg23,
              pins:                     :arg23,
              pin:                      :arg23,
              force_source:             :arg24,
              pcp_start:                :arg25,
              pcp_stop:                 :arg26,
              start_func_args:          :arg27,
              start_of_body_f_args:     :arg27,
              pre_pat_func_args:        :arg28,
              pre_pat_f_args:           :arg28,
              pre_test_func_args:       :arg29,
              pre_test_f_args:          :arg29,
              post_test_func_args:      :arg30,
              post_test_f_args:         :arg30,
              post_pat_func_args:       :arg31,
              post_pat_f_args:          :arg31,
              end_func_args:            :arg32,
              end_of_body_f_args:       :arg32,
              hsp_start:                :arg33,
              hsp_stop:                 :arg34,
              pcp_check_pg:             :arg35,
              clamp:                    :arg36,
              hsp_check_pg:             :arg37,
              resume_pat:               :arg38,
              relay_mode:               :arg39,
              utility_pins_1:           :arg40,
              utility_pins_0:           :arg41,
              test_control:             :arg42,
              serialize_meas:           :arg43,
              serialize_meas_func:      :arg44,
              serialize_meas_f:         :arg44,
              serialize_meas_func_args: :arg45,
              serialize_meas_f_args:    :arg45
            },

            mto_memory:       {
              patterns:                  :arg0,
              pattern:                   :arg0,
              start_func:                :arg1,
              start_of_body_f:           :arg1,
              pre_pat_func:              :arg2,
              pre_pat_f:                 :arg2,
              pre_test_func:             :arg3,
              pre_test_f:                :arg3,
              post_test_func:            :arg4,
              post_test_f:               :arg4,
              post_pat_func:             :arg5,
              post_pat_f:                :arg5,
              end_of_body_func:          :arg6,
              end_of_body_f:             :arg6,
              set_pass_fail:             :arg7,
              init_lo:                   :arg8,
              start_lo:                  :arg8,
              init_hi:                   :arg9,
              start_hi:                  :arg9,
              init_hiz:                  :arg10,
              start_hiz:                 :arg10,
              float_pins:                :arg11,
              start_of_body_func_args:   :arg12,
              start_of_body_f_args:      :arg12,
              pre_pat_func_args:         :arg13,
              pre_pat_f_args:            :arg13,
              pre_test_func_args:        :arg14,
              pre_test_f_args:           :arg14,
              post_test_func_args:       :arg15,
              post_test_f_args:          :arg15,
              post_pat_func_args:        :arg16,
              post_pat_f_args:           :arg16,
              end_of_body_func_args:     :arg17,
              end_of_body_f_args:        :arg17,
              utility_pins_1:            :arg18,
              utility_pins_0:            :arg19,
              wait_flags:                :arg20,
              wait_time_out:             :arg21,
              PatFlagF:                  :arg22,
              pat_flag_f:                :arg22,
              pat_flag_func_args:        :arg23,
              pat_flag_f_args:           :arg23,
              relay_mode:                :arg24,
              x_enable_mask:             :arg29,
              x_shift_direction:         :arg30,
              x_shift_input:             :arg31,
              y_enable_mask:             :arg36,
              y_shift_direction:         :arg37,
              y_shift_input:             :arg38,
              dga:                       :arg39,
              dgb:                       :arg40,
              dgc:                       :arg41,
              dgd:                       :arg42,
              dg_enable_mask:            :arg43,
              dg_shift_direction:        :arg44,
              dg_shift_input:            :arg45,
              x_coincidence_enable_mask: :arg46,
              y_coincidence_enable_mask: :arg47,
              two_bit_dg_setup:          :arg48,
              x_scramble_algorithm:      :arg49,
              y_scramble_algorithm:      :arg50,
              topo_inversion_algorithm:  :arg51,
              utility_counter_a:         :arg52,
              utility_counter_b:         :arg53,
              utility_counter_c:         :arg54,
              dut_data_source:           :arg55,
              scramble_addr:             :arg56,
              speed_mode:                :arg57,
              resource_map:              :arg58,
              receive_data:              :arg59,
              data_to_capture:           :arg60,
              capture_marker:            :arg61,
              enable_wrapping:           :arg62,
              capture_scrambled_address: :arg63,
              mapmem_0_input_set:        :arg64,
              mapmem_1_input_set:        :arg65,
              threading:                 :arg69,
              match_all_sites:           :arg70
            }
          }

          # HPT Support for Defaults
          if RGen::Tester::J750.hpt_mode
            template_type = 'Template'
            template_name_prefix = 'HPT.xla!HPT_'
          else
            template_type = 'IG-XL Template'
            template_name_prefix = ''
          end

          DEFAULTS = {
            empty:            {
              proc_type:      template_type,
              proc_name:      "#{template_name_prefix}Empty_T",
              proc_called_as: 'Excel Macro'
            },
            other:            {
              proc_type:      'Other',
              proc_called_as: 'Excel Macro'
            },
            functional:       {
              proc_type:       template_type,
              proc_name:       "#{template_name_prefix}Functional_T",
              proc_called_as:  'VB DLL',
              set_pass_fail:   1,
              wait_flags:      'XXXX',
              wait_time:       30,
              relay_mode:      1,
              threading:       0,
              match_all_sites: 0,
              capture_mode:    0,
              capture_what:    0,
              capture_memory:  0,
              capture_size:    256,
              datalog_mode:    0,
              data_type:       0
            },
            board_pmu:        {
              proc_type:        template_type,
              proc_name:        "#{template_name_prefix}BoardPmu_T",
              proc_called_as:   'VB DLL',
              wait_flags:       'XXXX',
              measure_mode:     1,
              irange:           5,
              vrange:           3,
              settling_time:    0,
              hi_lo_lim_valid:  3,
              gang_pins_tested: 0,
              relay_mode:       0,
              wait_time_out:    30,
              pcp_check_pg:     1,
              hsp_check_pg:     1,
              resume_pat:       0,
              threading:        0
            },
            pin_pmu:          {
              proc_type:       template_type,
              proc_name:       "#{template_name_prefix}PinPmu_T",
              proc_called_as:  'VB DLL',
              wait_flags:      'XXXX',
              measure_mode:    1,
              irange:          2,
              settling_time:   0,
              hi_lo_lim_valid: 3,
              fload:           0,
              relay_mode:      0,
              wait_time_out:   30,
              pcp_check_pg:    1,
              hsp_check_pg:    1,
              resume_pat:      0,
              threading:       0
            },
            apmu_powersupply: {
              proc_type:       template_type,
              proc_name:       "#{template_name_prefix}ApmuPowerSupply_T",
              proc_called_as:  'VB DLL',
              wait_flags:      'XXXX',
              irange:          1,
              settling_time:   0,
              hi_lo_lim_valid: 3,
              relay_mode:      0,
              wait_time_out:   30,
              pcp_check_pg:    1,
              hsp_check_pg:    1,
              resume_pat:      0,
              test_control:    0
            },
            mto_memory:       {
              proc_type:                 template_type,
              proc_name:                 "#{template_name_prefix}MtoMemory_T",
              proc_called_as:            'VB DLL',
              set_pass_fail:             1,
              wait_flags:                'XXXX',
              wait_time:                 30,
              relay_mode:                1,
              threading:                 0,
              match_all_sites:           0,
              dut_data_source:           0,
              scramble_addr:             0,
              speed_mode:                0,
              resource_map:              'MAP_1M_2BIT',
              receive_data:              0,
              data_to_capture:           1,
              capture_marker:            1,
              enable_wrapping:           0,
              capture_scrambled_address: 0,
              mapmem_0_input_set:        'Map_By16',
              mapmem_1_input_set:        'Map_By16',
              x_scramble_algorithm:      'X_NO_SCRAMBLE',
              y_scramble_algorithm:      'Y_NO_SCRAMBLE',
              topo_inversion_algorithm:  'NO_TOPO',
              x_shift_direction:         0,
              x_shift_input:             0,
              y_shift_direction:         0,
              y_shift_input:             0,
              x_coincidence_enable_mask: 0,
              y_coincidence_enable_mask: 0,
              dg_shift_direction:        0,
              dg_shift_input:            0
            }
          }

          # Generate accessors for all attributes and their aliases
          ATTRS.each do |attr|
            attr_accessor attr.to_sym
          end

          # Define the common aliases now, the instance type specific ones will
          # be created when the instance type is known
          ALIASES.each do |alias_, val|
            if val.is_a? Hash
            else
              define_method("#{alias_}=") do |v|
                send("#{val}=", v)
              end
              define_method("#{alias_}") do
                send(val)
              end
            end
          end

          def initialize(name, type, attrs = {})
            @type = type
            @append_version = true
            self.name = name
            # Build the type specific accessors (aliases)
            ALIASES[@type.to_sym].each do |alias_, val|
              define_singleton_method("#{alias_}=") do |v|
                send("#{val}=", v) if self.respond_to?("#{val}=", v)
              end
              define_singleton_method("#{alias_}") do
                send(val) if self.respond_to?(val)
              end
            end
            # Set the defaults
            DEFAULTS[@type.to_sym].each do |k, v|
              send("#{k}=", v) if self.respond_to?("#{k}=", v)
            end
            # Then the values that have been supplied
            attrs.each do |k, v|
              send("#{k}=", v) if self.respond_to?("#{k}=", v)
            end
          end

          def ==(other_instance)
            self.class == other_instance.class &&
              unversioned_name.to_s == other_instance.unversioned_name.to_s &&
              ATTRS.all? do |attr|
                # Exclude test name, already examined above and don't want to include
                # the version in the comparison
                if attr == 'test_name'
                  true
                else
                  send(attr) == other_instance.send(attr)
                end
              end
          end

          def self.new_empty(name, attrs = {})
            new(name, :empty, attrs)
          end

          def self.new_functional(name, attrs = {})
            new(name, :functional, attrs)
          end

          def self.new_board_pmu(name, attrs = {})
            new(name, :board_pmu, attrs)
          end

          def self.new_pin_pmu(name, attrs = {})
            new(name, :pin_pmu, attrs)
          end

          def self.new_apmu_powersupply(name, attrs = {})
            new(name, :apmu_powersupply, attrs)
          end

          def self.new_mto_memory(name, attrs = {})
            new(name, :mto_memory, attrs)
          end

          # Returns the fully formatted test instance for insertion into an instance sheet
          def to_s(override_name = nil)
            l = "\t"
            ATTRS.each do |attr|
              if attr == 'test_name' && override_name
                l += "#{override_name}\t"
              else
                l += "#{send(attr)}\t"
              end
            end
            "#{l}"
          end

          def name
            if version && @append_version
              "#{@test_name}_v#{version}"
            else
              @test_name.to_s
            end
          end
          alias_method :test_name, :name

          def unversioned_name
            @test_name.to_s
          end

          # Set the cpu wait flags for the given test instance
          #   instance.set_wait_flags(:a)
          #   instance.set_wait_flags(:a, :c)
          def set_wait_flags(*flags)
            a = (flags.include?(:a) || flags.include?(:a)) ? '1' : 'X'
            b = (flags.include?(:b) || flags.include?(:b)) ? '1' : 'X'
            c = (flags.include?(:c) || flags.include?(:c)) ? '1' : 'X'
            d = (flags.include?(:d) || flags.include?(:d)) ? '1' : 'X'
            self.wait_flags = d + c + b + a
            self
          end

          # Set and enable the pre-charge voltage of a parametric test instance.
          def set_pre_charge(val)
            if val
              self.pre_charge_enable = 1
              self.pre_charge = val
            else
              self.pre_charge_enable = 0
            end
            self
          end
          alias_method :set_precharge, :set_pre_charge

          # Set and enable the hi limit of a parametric test instance, passing in
          # nil or false as the lim parameter will disable the hi limit.
          def set_hi_limit(lim)
            if lim
              self.hi_lo_limit_valid = hi_lo_limit_valid | 2
              self.hi_limit = lim
            else
              self.hi_lo_limit_valid = hi_lo_limit_valid & 1
            end
            self
          end

          # Set and enable the hi limit of a parametric test instance, passing in
          # nil or false as the lim parameter will disable the hi limit.
          def set_lo_limit(lim)
            if lim
              self.hi_lo_limit_valid = hi_lo_limit_valid | 1
              self.lo_limit = lim
            else
              self.hi_lo_limit_valid = hi_lo_limit_valid & 2
            end
            self
          end

          # Set the current range of the test instance, the following are valid:
          #
          # Board PMU
          # * 2uA
          # * 20uA
          # * 200uA
          # * 2mA
          # * 20mA
          # * 200mA
          # * :smart
          #
          # Pin PMU
          # * 200nA
          # * 2uA
          # * 20uA
          # * 200uA
          # * 2mA
          # * :auto
          # * :smart
          #
          # Examples
          #   instance.set_irange(:smart)
          #   instance.set_irange(:ua => 2)
          #   instance.set_irange(2.uA) # Same as above
          #   instance.set_irange(:ma => 200)
          #   instance.set_irange(0.2) # Same as above
          #   instance.set_irange(:a => 0.2) # Same as above
          def set_irange(r = nil, options = {})
            r, options = nil, r if r.is_a?(Hash)
            unless r
              # rubocop:disable AssignmentInCondition
              if r = options.delete(:na) || options.delete(:nA)
                r = r / 1_000_000_000
              elsif r = options.delete(:ua) || options.delete(:uA)
                r = r / 1_000_000.0
              elsif r = options.delete(:ma) || options.delete(:mA)
                r = r / 1000.0
              elsif r = options.delete(:a) || options.delete(:A)
              else
                fail "Can't determine requested irange!"
              end
              # rubocop:enable AssignmentInCondition
            end

            if @type == :board_pmu
              if r == :smart
                self.irange = 6
              else
                self.irange = case
                  when r > 0.02 then 5
                  when r > 0.002 then 4
                  when r > 0.0002 then 3
                  when r > 0.00002 then 2
                  when r > 0.000002 then 1
                  else 0
                  end
              end

            else # :pin_pmu
              if r == :smart
                self.irange = 5
              elsif r == :auto
                fail 'Auto range not available in FIMV mode!' if self.fimv?
                self.irange = 6
              else
                if fimv?
                  self.irange = case
                    when r > 0.0002 then 2
                    else 4
                    end
                else
                  self.irange = case
                    when r > 0.0002 then 2
                    when r > 0.00002 then 4
                    when r > 0.000002 then 0
                    when r > 0.0000002 then 1
                    else 3
                    end
                end
              end
            end

            self
          end

          # Set the voltage range of the test instance, the following are valid:
          #
          # Board PMU
          # * 2V
          # * 5V
          # * 10V
          # * 24V
          # * :auto
          # * :smart
          #
          # Examples
          #   instance.set_vrange(:auto)
          #   instance.set_vrange(:v => 5)
          #   instance.set_vrange(5) # Same as above
          def set_vrange(r = nil, options = {})
            r, options = nil, r if r.is_a?(Hash)
            if r == :smart
              self.vrange = 4
            elsif r == :auto
              self.vrange = 5
            elsif !r
              r = options.delete(:v) || options.delete(:V)
              if r
              else
                fail "Can't determine requested vrange!"
              end
            end
            self.vrange = case
              when r > 10 then 3
              when r > 5 then 2
              when r > 2 then 1
              else 0
              end
            self
          end

          # Set the meaure mode of a parametric test instance, either:
          # * :voltage / :fimv
          # * :current / :fvmi
          def set_measure_mode(mode)
            if mode == :current || mode == :fvmi
              self.measure_mode = 0
            elsif mode == :voltage || mode == :fimv
              self.measure_mode = 1
            else
              fail "Unknown measure mode: #{mode}"
            end
          end

          # Returns true if instance configured for force current, measure voltage
          def fimv?
            measure_mode == 1
          end

          # Returns true if instance configured for force voltage, measure current
          def fvmi?
            measure_mode == 0
          end
        end
      end
    end
  end
end
