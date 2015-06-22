module Origen
  module Specs
    # This class is used to store text information to help with documentation processes
    class Doc_Resource
      attr_accessor :mode, :type, :sub_type, :audience, :table_title
      attr_accessor :note_refs, :exhibit_refs, :before_table, :after_table, :doc_options

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

      def to_xml
        tmp = {}
        tmp['mode'] = @mode unless @mode.nil?
        tmp['type'] = @type unless @type.nil?
        tmp['sub_type'] = @sub_type unless @sub_type.nil?
        tmp['audience'] = @audience unless @audience.nil?
        doc_resource_ml = Nokogiri::XML::Builder.new do |xml|
          xml.doc_resource(tmp.each do |t, d|
            "#{t}=\"#{d}\""
          end
                          ) do
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
              end  # unless @note_refs.to_s.size == 0
            end # unless @table_title.nil? && @note_refs.size == 0 && @exhibit_refs.size == 0
            unless @before_table.nil? && @after_table.nil?
              xml.paragraphs do
                unless @before_table.nil?
                  if @before_table.is_a? Nokogiri::XML::Node
                    xml.before_table @before_table.inner_html
                  else
                    xml.before_table @before_table
                  end
                end
                unless @after_table.nil?
                  if @after_table.is_a? Nokogiri::XML::Node
                    xml.after_table after_table.inner_html
                  else
                    xml.after_table @after_table
                  end
                end
              end # xml.paragraphs do
            end # unless @before_table.nil? && @after_table.nil?
          end # xml.doc_resource
        end # doc_resource_ml = Nokogiri::
        doc_resource_ml
      end  # to_xml
    end
  end
end
