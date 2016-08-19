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

module Origami

    class OutputIntent < Dictionary
        include StandardObject

        module Intent
            PDFX = :GTS_PDFX
            PDFA1 = :GTS_PDFA1
            PDFE1 = :GTS_PDFE1
        end

        field :Type,                      :Type => Name, :Default => :OutputIntent
        field :S,                         :Type => Name, :Version => '1.4', :Required => true
        field :OutputCondition,           :Type => String
        field :OutputConditionIdentifier, :Type => String
        field :RegistryName,              :Type => String
        field :Info,                      :Type => String
        field :DestOutputProfile,         :Type => Stream
    end

    class PDF
        def pdfa1?
            self.Catalog.OutputIntents.is_a?(Array) and
            self.Catalog.OutputIntents.any?{|intent|
                intent.solve.S == OutputIntent::Intent::PDFA1
            } and
            self.metadata? and (
                doc = REXML::Document.new self.Catalog.Metadata.data;
                REXML::XPath.match(doc, "*/*/rdf:Description[@xmlns:pdfaid]").any? {|desc|
                    desc.elements["pdfaid:conformance"].text == "A" and
                    desc.elements["pdfaid:part"].text == "1"
                }
            )
        end

        private

        def intents_as_pdfa1
            return if self.pdfa1?

            self.Catalog.OutputIntents ||= []
            self.Catalog.OutputIntents << self.insert(
                OutputIntent.new(
                    :Type => :OutputIntent,
                    :S => OutputIntent::Intent::PDFA1,
                    :OutputConditionIdentifier => "RGB"
                )
            )

            metadata = self.create_metadata
            doc = REXML::Document.new(metadata.data)

            desc = REXML::Element.new 'rdf:Description'
            desc.add_attribute 'rdf:about', ''
            desc.add_attribute 'xmlns:pdfaid', 'http://www.aiim.org/pdfa/ns/id/'
            desc.add REXML::Element.new('pdfaid:conformance').add_text('A')
            desc.add REXML::Element.new('pdfaid:part').add_text('1')
            doc.elements["*/rdf:RDF"].add desc

            xml = ""; doc.write(xml, 3)
            metadata.data = xml
        end
    end

end
