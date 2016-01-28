module Origen
  module Specs
    # Ruby Data Class that contains Creation Information for the IP Block
    class Creation_Info
      attr_accessor :author, :date, :revision, :source, :tool, :tool_version, :ip_version, :ip_block_name

      # Initialize the Creation Info block to store data for latest version of the file.
      #
      # ==== Parameters
      #
      # * author    # Author/Subject Matter Expert for the IP Block
      # * date      # Date that the File was released to Downstream Audiences
      # ==== Source Information
      #
      # * :revision      # Revision Information
      # * :source        # Where the Information came from
      # * :ip_block_name # Block Name for the IP. e.g. DDR for DDRC1, DDRC2; I2C for I2C1, I2C2
      #
      # ==== Tool Info
      #
      # * :tool      # Tool that created the initial XML file
      # * :version   # Version of the Tool that created the XML file
      #
      # ==== Example
      #
      #   Creation_Info.new("author", "07/10/2015", :revision => "5.4", :source => "CSV", :tool => "oRiGeN", :tool_version => "0.0.6")
      def initialize(author, date, ip_version, src_info = {}, tool_info = {})
        @author = author
        @date = date
        @ip_version = ip_version
        @revision = src_info[:revision]
        @source = src_info[:source]
        @ip_block_name = src_info[:ip_block_name]
        @tool = tool_info[:tool]
        @tool_version = tool_info[:version]
      end
    end
  end
end
