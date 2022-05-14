module Origen
  module Specs
    # This class is used to store text information to help with documentation processes
    class Doc_Resource
      # Mode is part of the 4-D Hash for the Tables.  Corresponds to Spec 4-D Hash
      attr_accessor :mode

      # Type is part of the 4-D Hash for the Tables.  Corresponds to Spec 4-D Hash
      # Usual values
      #
      # * DC -> Direct Current
      # * AC -> Alternate Current
      # * Temp -> Temperature
      # * Supply -> Supply
      attr_accessor :type

      # SubType is part of the 4-D Hash for the Tables. Corresponds to Spec 4-D Hash
      attr_accessor :sub_type

      # Audience is part of the 4-D Hash for the Tables.  Corresponds to Spec 4-D Hash
      attr_accessor :audience

      # Table Title that should appear for the table.  If blank, generic Table Title will be used
      # Hash is created from mode, type, sub_type, and audience.
      attr_accessor :table_title

      # Note References that should be referenced within the table title
      attr_accessor :note_refs

      # Exhibit References that should be referenced within the table title
      attr_accessor :exhibit_refs

      # DITA Formatted Text that appears before the table
      attr_accessor :before_table

      # DITA Formatted Text that appears after the table
      attr_accessor :after_table

      # Documentation Options that will change the appearance of the output.
      attr_accessor :doc_options

      # Initialize the Class
      def initialize(selector = {}, table_title = {}, text = {}, options = {})
        @mode = selector[:mode]
        @type = selector[:type]
        @sub_type = selector[:sub_type]
        @audience = selector[:audience]
        @table_title = table_title[:title]
        @note_refs = table_title[:note_refs]
        @exhibit_refs = table_title[:exhibit_refs]
        @before_table = text[:before]
        @after_table = text[:after]
        @doc_options = options
      end

      # Converts to an XML file.
      def to_xml
        tmp = {}
        tmp['mode'] = @mode unless @mode.nil?
        tmp['type'] = @type unless @type.nil?
        tmp['sub_type'] = @sub_type unless @sub_type.nil?
        tmp['audience'] = @audience unless @audience.nil?
        doc_resource_ml = Nokogiri::XML::Builder.new do |xml|
          xml.doc_resource(tmp.each do |t, d|
            "#{t}=\"#{d}\""     # rubocop:disable Lint/Void
          end) do
            unless @table_title.nil? && @note_refs.size == 0 && @exhibit_refs.size == 0
              unless @note_refs.first.to_s.size == 0
                unless @exhibit_refs.first.to_s.size == 0
                  xml.title do
                    unless @table_title.nil?
                      xml.Text @table_title.to_s
                    end
                    unless @note_refs.size == 0
                      unless @note_refs.first.to_s.size == 0
                        xml.noteRefs do
                          @note_refs = [@note_refs] unless @note_refs.is_a? Array
                          @note_refs.each do |note_ref|
                            unless note_ref.to_s.size == 0
                              xml.noteRef(href: note_ref.to_s)
                            end # unless note_ref.to_s.size == 0
                          end # @note_refs.each do |note_ref|
                        end # xml.noteRefs do
                      end # unless @note_refs.first.to_s.size == 0
                    end # unless @note_refs.size == 0
                    unless @exhibit_refs.size == 0
                      unless @exhibit_refs.first.to_s.size == 0
                        xml.exhibitRefs do
                          @exhibit_refs = [@exhibit_refs] unless @exhibit_refs.is_a? Array
                          @exhibit_refs.each do |exhibit_ref|
                            unless exhibit_ref.to_s.size == 0
                              xml.exhibitRef(href: exhibit_ref.to_s)
                            end # unless exhibit_ref.to_s.size == 0
                          end # @exhibit_refs.each do |exhibit_ref|
                        end # xml.exhibitRefs do
                      end # unless @exhibit_refs.first.to_s.size == 0
                    end # unless @exhibit_refs.size == 0
                  end # xml.title.done
                end # unless @exhibit_refs.to_s.size == 0
              end # unless @note_refs.to_s.size == 0
            end # unless @table_title.nil? && @note_refs.size == 0 && @exhibit_refs.size == 0
            unless @before_table.nil? && @after_table.nil?
              xml.paragraphs do
                unless @before_table.nil?
                  if (@before_table.is_a? Nokogiri::XML::Node) || (@before_table.is_a? Nokogiri::XML::Element)
                    xml.before_table do
                      if @before_table.name == 'body'
                        xml << @before_table.children.to_xml
                      else
                        xml << @before_table.to_xml
                      end
                    end
                  else
                    xml.before_table @before_table
                  end
                end
                unless @after_table.nil?
                  if (@after_table.is_a? Nokogiri::XML::Node) || (@after_table.is_a? Nokogiri::XML::Element)
                    xml.after_table do
                      if @after_table.name == 'body'
                        xml << @after_table.children.to_xml
                      else
                        xml << @after_table.to_xml
                      end
                    end
                  else
                    xml.after_table @after_table
                  end
                end
              end # xml.paragraphs do
            end # unless @before_table.nil? && @after_table.nil?
          end # xml.doc_resource
        end # doc_resource_ml = Nokogiri::
        doc_resource_ml.doc.at_xpath('doc_resource').to_xml
      end  # to_xml
    end
  end
end
