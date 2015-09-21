module Origen
  module GlobalMethods
    require_relative 'encodings'
    def annotate(msg, options = {})
      Origen.app.tester.annotate(msg, options)
    end

    def c1(msg, options = {})
      Origen.app.tester.c1(msg, options)
    end
    alias_method :cc, :c1

    def c2(msg, options = {})
      Origen.app.tester.c2(msg, options)
    end

    def ss(*args, &block)
      Origen.app.tester.ss(*args, &block)
    end
    alias_method :step_comment, :ss

    def pp(*args, &block)
      Origen.app.tester.pattern_section(*args, &block)
    end
    alias_method :pattern_section, :pp
    alias_method :ps, :pp

    def snip(*args, &block)
      Origen.app.tester.snip(*args, &block)
    end

    # Render an ERB template
    def render(*args, &block)
      Origen.generator.compiler.render(*args, &block)
    end

    def dut
      Origen.top_level
    end

    def tester
      Origen.tester
    end

    # The options passed to an ERB template. Having it
    # global like this is ugly, but it does allow a hash of options
    # to always be available in templates even if the template
    # is being rendered using a custom binding.
    #
    # @api private
    def options
      $_target_options ||
        Origen.generator.compiler.options
    end

    def global_binding
      binding
    end

    Pattern = Origen.pattern unless defined?(Pattern)
    Flow = Origen.flow unless defined?(Flow)
    Resources = Origen.resources unless defined?(Resources)
    User = Origen::Users::User unless defined?(User)
  end
end
