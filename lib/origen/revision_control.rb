module Origen
  module RevisionControl
    require 'origen/revision_control/base'
    autoload :DesignSync, 'origen/revision_control/design_sync'
    autoload :Git,        'origen/revision_control/git'
    autoload :Subversion, 'origen/revision_control/subversion'
    autoload :Perforce,   'origen/revision_control/perforce'

    IGNORE_DIRS =  %w(
      .ws .lsf log output web coverage .ref .yardoc .collection .bin
      .session .bundle .tpc pkg tmp .git
    )

    IGNORE_FILES = %w(
      target/.default release_note.txt *.swp *.swo *~ .bin
      list/referenced.list tags .ref .pdm/pi_attributes.txt
      environment/.default
    )

    # Creates a new revision controller object based on the supplied :local and :remote
    # options.
    #
    # The revision control system will be worked out from the supplied remote value. This method
    # should therefore be used whenever the remote is a variable that could refer to many different
    # systems.
    #
    # @example
    #
    #   # I know that the remote refers to DesignSync
    #   rc = Origen::RevisionControl::DesignSync.new remote: "sync//....", local: "my/path"
    #
    #   # The remote is a variable and I don't know the type
    #   rc = Origen::RevisionControl.new remote: rc_url, local: "my/path"
    def self.new(options = {})
      case
      when options[:remote] =~ /^sync/
        DesignSync.new(options)
      when options[:remote] =~ /git/
        Git.new(options)
      when options[:remote] =~ /^p4/
        Perforce.new(options)
      else
        fail "Could not work out the revision control system for: #{options[:remote]}"
      end
    end
  end
end
