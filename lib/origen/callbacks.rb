require 'active_support/concern'
module Origen
  module Callbacks
    extend ActiveSupport::Concern

    included do
      include Origen::ModelInitializer
    end

    def register_callback_listener # :nodoc:
      Origen.app.add_callback_listener(self)
      # If this object has been instantiated after on_create has already been called,
      # then invoke it now
      if Origen.app.on_create_called?
        if respond_to?(:on_create)
          unless @_on_create_called
            @_on_create_called = true
            on_create
          end
        end
      end
    end
  end

  # The regular callbacks module will register listeners that expire upon the next target
  # load, normally this is what is wanted at app level since things should start afresh
  # every time the target is loaded.
  #
  # However within Origen core (and possibly some plugins) it is often the case that registered
  # listeners will be objects that are not re-instantiated upon target load and persist for
  # the entire Origen thread. In this case use the PersistentCallbacks module instead of the regular
  # Callbacks module to make these objects register as permanent listeners.
  module PersistentCallbacks
    extend ActiveSupport::Concern

    included do
      include Origen::ModelInitializer
    end

    def register_callback_listener # :nodoc:
      Origen.app.add_persistant_callback_listener(self)
    end
  end
  CoreCallbacks = PersistentCallbacks
end
