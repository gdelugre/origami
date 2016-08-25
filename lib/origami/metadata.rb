=begin

    This file is part of Origami, PDF manipulation framework for Ruby
    Copyright (C) 2016	Guillaume Delugré.

    Origami is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Origami is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Origami.  If not, see <http://www.gnu.org/licenses/>.

=end

require 'rexml/document'

module Origami

    class PDF
        #
        # Returns true if the document has a document information dictionary.
        #
        def document_info?
            trailer_key? :Info
        end

        #
        # Returns the document information dictionary if present.
        #
        def document_info
            trailer_key :Info
        end

        def title; get_document_info_field(:Title) end
        def author; get_document_info_field(:Author) end
        def subject; get_document_info_field(:Subject) end
        def keywords; get_document_info_field(:Keywords) end
        def creator; get_document_info_field(:Creator) end
        def producer; get_document_info_field(:Producer) end
        def creation_date; get_document_info_field(:CreationDate) end
        def mod_date; get_document_info_field(:ModDate) end

        #
        # Returns true if the document has a catalog metadata stream.
        #
        def metadata?
            self.Catalog.Metadata.is_a?(Stream)
        end

        #
        # Returns a Hash of the information found in the metadata stream
        #
        def metadata
            metadata_stm = self.Catalog.Metadata

            if metadata_stm.is_a?(Stream)
                doc = REXML::Document.new(metadata_stm.data)
                info = {}

                doc.elements.each('*/*/rdf:Description') do |description|

                    description.attributes.each_attribute do |attr|
                        case attr.prefix
                        when 'pdf','xap'
                            info[attr.name] = attr.value
                        end
                    end

                    description.elements.each('*') do |element|
                        value = (element.elements['.//rdf:li'] || element).text
                        info[element.name] = value.to_s
                    end
                end

                info
            end
        end

        #
        # Modifies or creates a metadata stream.
        #
        def create_metadata(info = {})
            skeleton = <<-XMP
            <?packet begin="\xef\xbb\xbf" id="W5M0MpCehiHzreSzNTczkc9d"?>
              <x:xmpmeta xmlns:x="adobe:ns:meta/">
                <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                  <rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
                  </rdf:Description>
                </rdf:RDF>
              </x:xmpmeta>
            <?xpacket end="w"?>
            XMP

            xml =
                if self.Catalog.Metadata.is_a?(Stream)
                    self.Catalog.Metadata.data
                else
                    skeleton
                end

            doc = REXML::Document.new(xml)
            desc = doc.elements['*/*/rdf:Description']

            info.each do |name, value|
                elt = REXML::Element.new "pdf:#{name}"
                elt.text = value

                desc.elements << elt
            end

            xml = ""; doc.write(xml, 4)

            if self.Catalog.Metadata.is_a?(Stream)
                self.Catalog.Metadata.data = xml
            else
               self.Catalog.Metadata = Stream.new(xml)
            end

            self.Catalog.Metadata
        end

        private

        def get_document_info_field(field) #:nodoc:
            if self.document_info?
                doc_info = self.document_info

                if doc_info.key?(field)
                    case obj = doc_info[field].solve
                    when String then obj.value
                    when Stream then obj.data
                    end
                end
            end
        end
    end

    #
    # Class representing an information Dictionary, containing title, author, date of creation and the like.
    #
    class Metadata < Dictionary
        include StandardObject

        field   :Title,                   :Type => String, :Version => "1.1"
        field   :Author,                  :Type => String
        field   :Subject,                 :Type => String, :Version => "1.1"
        field   :Keywords,                :Type => String, :Version => "1.1"
        field   :Creator,                 :Type => String
        field   :Producer,                :Type => String
        field   :CreationDate,            :Type => String
        field   :ModDate,                 :Type => String, :Version => "1.1"
        field   :Trapped,                 :Type => Name, :Default => :Unknown, :Version => "1.3"
    end

    #
    # Class representing a metadata Stream.
    # This stream can contain the same information as the Metadata dictionary, but is storing in XML data.
    #
    class MetadataStream < Stream
        include StandardObject

        field   :Type,                    :Type => Name, :Default => :Metadata, :Required => true
        field   :Subtype,                 :Type => Name, :Default =>:XML, :Required => true
    end

end
