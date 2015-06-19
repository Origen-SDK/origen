module RGen
  module Specs
    # This class is used to store spec note information used to document IP
    class Creation_Info
      attr_accessor :author, :date, :revision, :source, :tool, :tool_version

      def initialize(author, date, src_info = {}, tool_info = {})
        @author = author
        @date = date
        @revision = src_info[:revision]
        @source = src_info[:source]
        @tool = tool_info[:tool]
        @tool_version = tool_info[:version]
      end
    end
  end
end
