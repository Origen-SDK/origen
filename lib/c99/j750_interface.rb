module C99
  module J750BaseInterface
    # Options passed to Flow.create and Library.create will be passed in here, use as
    # desired to configure your interface
    def initialize(_options = {})
    end

    def log(msg)
      flow.logprint(msg)
    end

    def func(name, options = {})
      options = {
        duration: :static
      }.merge(options)

      block_loop(name, options) do |_block, i, group|
        ins = test_instances.functional(name)
        ins.set_wait_flags(:a) if options[:duration] == :dynamic
        ins.pin_levels = options.delete(:pin_levels) if options[:pin_levels]
        if group
          pname = "#{name}_b#{i}_pset"
          patsets.add(pname, [{ pattern: "#{name}_b#{i}.PAT" },
                              { pattern: 'nvm_global_subs.PAT', start_label: 'subr' }])
          ins.pattern = pname
          flow.test(group, options) if i == 0
        else
          pname = "#{name}_pset"
          patsets.add(pname, [{ pattern: "#{name}.PAT" },
                              { pattern: 'nvm_global_subs.PAT', start_label: 'subr' }])
          ins.pattern = pname
          if options[:cz_setup]
            flow.cz(ins, options[:cz_setup], options)
          else
            flow.test(ins, options)
          end
        end
      end
    end

    def block_loop(name, options)
      if options[:by_block]
        test_instances.group do |group|
          group.name = name
          $nvm.blocks.each_with_index do |block, i|
            yield block, i, group
          end
        end
      else
        yield
      end
    end

    def por(options = {})
      options = {
        instance_not_available: true
      }.merge(options)
      flow.test('por_ins', options)
    end

    def para(name, options = {})
      options = {
        high_voltage: false
      }.merge(options)
      if options.delete(:high_voltage)
        ins = test_instances.bpmu(name)
      else
        ins = test_instances.ppmu(name)
      end
      ins.dc_category = 'NVM_PARA'
      flow.test(ins, options)
      patsets.add("#{name}_pset", pattern: "#{name}.PAT")
    end
  end

  class J750Interface
    include J750BaseInterface
    include Origen::Tester::J750::Generator
  end

  class TestersJ750Interface
    include J750BaseInterface
    include Testers::J750::Generator
  end
end
