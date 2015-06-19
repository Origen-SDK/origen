module C99
  class DocInterface
    include RGen::Tester::Doc::Generator

    # Options passed to Flow.create and Library.create will be passed in here, use as
    # desired to configure your interface
    def initialize(_options = {})
    end

    def resources_filename=(*_args)
    end

    def log(_msg)
    end

    def func(name, options = {})
      options = {
        duration: :static
      }.merge(options)

      block_loop(name, options) do |_block, i, group|
        ins = tests.add(name, options)
        if group
          flow.test(group, options) if i == 0
        else
          flow.test(ins, options)
        end
      end
    end

    def block_loop(name, options)
      if options[:by_block]
        tests.group do |group|
          group.name = name
          $nvm.blocks.each_with_index do |block, i|
            yield block, i, group
          end
        end
      else
        yield
      end
    end

    def por(_options = {})
    end

    def para(name, options = {})
      options = {
        high_voltage: false
      }.merge(options)
      ins = tests.add(name, options)
      ins.dc_category = 'NVM_PARA'
      flow.test(ins, options)
    end
  end
end
