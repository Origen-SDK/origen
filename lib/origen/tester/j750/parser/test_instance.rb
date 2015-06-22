module Origen
  module Tester
    class J750
      class Parser
        class TestInstance
          attr_accessor :parser

          TYPES = %w(
            functional board_pmu empty pin_pmu power_supply mto_memory
          )

          TYPE_ALIASES = {
            functional_t:         :functional,
            boardpmu_t:           :board_pmu,
            nvmboardpmucal_t:     :board_pmu,
            nvmboardpmumeasure_t: :board_pmu,
            empty_t:              :empty,
            pinpmu_t:             :pin_pmu,
            nvmpinpmucal_t:       :pin_pmu,
            nvmpinpmumeas_t:      :pin_pmu,
            powersupply_t:        :power_supply,
            mtomemory_t:          :mto_memory
          }

          attributes = %w(
            test_name proc_type proc_name proc_called_as dc_category dc_selector ac_category ac_selector
            time_sets edge_sets pin_levels overlay
          )
          80.times do |i|
            attributes << "arg#{i}"
          end
          attributes << 'comment'

          ATTRS = attributes

          ALIASES = {
            name:       :test_name,

            functional: {
              pattern:             :arg0,
              start_func:          :arg1,
              pre_pat_func:        :arg2,
              pre_test_func:       :arg3,
              post_test_func:      :arg4,
              post_pat_func:       :arg5,
              end_func:            :arg6,
              set_pass_fail:       :arg7,
              start_func_args:     :arg13,
              pre_pat_func_args:   :arg14,
              pre_test_func_args:  :arg15,
              post_test_func_args: :arg16,
              post_pat_func_args:  :arg17,
              end_func_args:       :arg18,
              wait_flags:          :arg21,
              wait_time:           :arg22,
              pat_flag_func:       :arg23,
              pat_flag_func_args:  :arg24,
              relay_mode:          :arg25,
              threading:           :arg26,
              match_all_sites:     :arg27,
              capture_mode:        :arg30,
              capture_what:        :arg31,
              capture_memory:      :arg32,
              capture_size:        :arg33,
              datalog_mode:        :arg34,
              data_type:           :arg35
            },

            board_pmu:  {
              hsp_start:           :arg0,
              start_func:          :arg1,
              pre_pat_func:        :arg2,
              pre_test_func:       :arg3,
              post_test_func:      :arg4,
              post_pat_func:       :arg5,
              end_func:            :arg6,
              precond_pat:         :arg7,
              hold_state_pat:      :arg8,
              holdstate_pat:       :arg8,
              pattern:             :arg8,
              pcp_stop:            :arg9,
              wait_flags:          :arg10,
              start_lo:            :arg11,
              init_lo:             :arg11,
              start_hi:            :arg12,
              init_hi:             :arg12,
              start_hiz:           :arg13,
              init_hiz:            :arg13,
              float_pins:          :arg14,
              pinlist:             :arg15,
              measure_mode:        :arg16,
              irange:              :arg17,
              clamp:               :arg18,
              vrange:              :arg19,
              sampling_time:       :arg20,
              samples:             :arg21,
              setting_time:        :arg22,
              hi_lo_lim_valid:     :arg23,
              hi_limit:            :arg24,
              lo_limit:            :arg25,
              force_cond_1:        :arg26,
              force_cond_2:        :arg27,
              gang_pins_tested:    :arg28,
              relay_mode:          :arg29,
              wait_time_out:       :arg30,
              start_func_args:     :arg31,
              pre_pat_func_args:   :arg32,
              pre_test_func_args:  :arg33,
              post_test_func_args: :arg34,
              post_pat_func_args:  :arg35,
              end_func_args:       :arg36,
              pcp_start:           :arg37,
              pcp_check_pg:        :arg38,
              hsp_stop:            :arg39,
              hsp_check_pg:        :arg40,
              resume_pat:          :arg41,
              utility_pins_1:      :arg42,
              utility_pins_0:      :arg43,
              pre_charge_enable:   :arg44,
              pre_charge:          :arg45,
              threading:           :arg46
            },

            pin_pmu:    {
              hsp_start:           :arg0,
              start_func:          :arg1,
              pre_pat_func:        :arg2,
              pre_test_func:       :arg3,
              post_test_func:      :arg4,
              post_pat_func:       :arg5,
              end_func:            :arg6,
              precond_pat:         :arg7,
              hold_state_pat:      :arg8,
              holdstate_pat:       :arg8,
              pattern:             :arg8,
              pcp_stop:            :arg9,
              wait_flags:          :arg10,
              start_lo:            :arg11,
              init_lo:             :arg11,
              start_hi:            :arg12,
              init_hi:             :arg12,
              start_hiz:           :arg13,
              init_hiz:            :arg13,
              float_pins:          :arg14,
              pinlist:             :arg15,
              measure_mode:        :arg16,
              irange:              :arg17,
              setting_time:        :arg18,
              hi_lo_lim_valid:     :arg19,
              hi_limit:            :arg20,
              lo_limit:            :arg21,
              force_cond_1:        :arg22,
              force_cond_2:        :arg23,
              fload:               :arg24,
              f_load:              :arg24,
              relay_mode:          :arg25,
              wait_time_out:       :arg26,
              start_func_args:     :arg27,
              pre_pat_func_args:   :arg28,
              pre_test_func_args:  :arg29,
              post_test_func_args: :arg30,
              post_pat_func_args:  :arg31,
              end_func_args:       :arg32,
              pcp_start:           :arg33,
              pcp_check_pg:        :arg34,
              hsp_stop:            :arg35,
              hsp_check_pg:        :arg36,
              sampling_time:       :arg37,
              samples:             :arg38,
              resume_pat:          :arg39,
              vcl:                 :arg40,
              vch:                 :arg41,
              utility_pins_1:      :arg42,
              utility_pins_0:      :arg43,
              pre_charge_enable:   :arg44,
              pre_charge:          :arg45,
              threading:           :arg46
            },
            mto_memory: {
              pattern:                   :arg0,
              start_func:                :arg1,
              pre_pat_func:              :arg2,
              pre_test_func:             :arg3,
              post_test_func:            :arg4,
              post_pat_func:             :arg5,
              end_of_body_func:          :arg6,
              set_pass_fail:             :arg7,
              float_pins:                :arg11,
              start_of_body_func_args:   :arg12,
              pre_pat_func_args:         :arg13,
              pre_test_func_args:        :arg14,
              post_test_func_args:       :arg15,
              post_pat_func_args:        :arg16,
              end_of_body_func_args:     :arg17,
              utility_pins_1:            :arg18,
              utility_pins_0:            :arg19,
              wait_flags:                :arg20,
              wait_time_out:             :arg21,
              pat_flag_f:                :arg22,
              pat_flag_func_args:        :arg23,
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

          # Make readers for each low level attribute
          ATTRS.each do |attr|
            attr_reader attr
          end

          # And the aliases
          ALIASES.each do |_alias, attr|
            define_method("#{_alias}") do
              send(attr)
            end
          end

          def initialize(line, options = {})
            @parser = options[:parser]
            @line = line
            parse
            if valid?
              ATTRS.each_with_index do |attr, i|
                instance_variable_set("@#{attr}", components[i + 1])
              end
              if ALIASES[type]
                ALIASES[type].each do |_alias, attr|
                  define_singleton_method("#{_alias}") do
                    send(attr)
                  end
                end
              end
            end
          end

          def inspect  # :nodoc:
            "<TestInstance: #{name}, Type: #{type}>"
          end

          def description
            parser.descriptions.test_instance(name: name)
          end

          def type
            TYPE_ALIASES[proc_name.downcase.to_sym] || :unsupported
          end

          def parse
            @components = @line.split("\t") unless @line.strip.empty?
          end

          def valid?
            components[4] && ['Excel Macro', 'VB DLL'].include?(components[4])
          end

          def components
            @components ||= []
          end

          # Returns an array of all pattern names referenced in this test instance
          def patterns
            if self.respond_to?(:pattern)
              pattern.split(',').map do |pat|
                extract_pattern_from_patset(pat)
              end.flatten.map { |pat| pat.gsub(/.*[\\\/]/, '').gsub(/\..*/, '') }
            end
          end

          def extract_pattern_from_patset(patset)
            pset = parser.pattern_sets.where(name: patset, exact: true)
            if pset.size > 1
              puts "Warning multiple pattern sets called #{patset} found, using the first one"
            end
            if pset.size == 0
              patset
            else
              pset.first.pattern_names
            end
          end

          def vdd
            parser.dc_specs.where(name: 'VDD', exact: true).first.lookup(dc_category, dc_selector)
          end
        end
      end
    end
  end
end
