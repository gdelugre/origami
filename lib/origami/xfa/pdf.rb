=begin

    This file is part of Origami, PDF manipulation framework for Ruby
    Copyright (C) 2017	Guillaume Delugré.

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

    module XDP

        module Packet

            #
            # An XDF _pdf_ element encloses a PDF packet.
            #
            class PDF < XFA::Element
                mime_type 'application/pdf'
                xfa_attribute :href

                def initialize
                    super("pdf")

                    add_attribute 'xmlns', 'http://ns.adobe.com/xdp/pdf/'
                end

                def enclose_pdf(pdfdata)
                    require 'base64'
                    b64data = Base64.encode64(pdfdata).chomp!

                    doc = elements['document'] || add_element('document')
                    chunk = doc.elements['chunk'] || doc.add_element('chunk')

                    chunk.text = b64data

                    self
                end

                def has_enclosed_pdf?
                    chunk = elements['document/chunk']

                    not chunk.nil? and not chunk.text.nil?
                end

                def remove_enclosed_pdf
                    elements.delete('document') if has_enclosed_pdf?
                end

                def enclosed_pdf
                    return nil unless has_enclosed_pdf?

                    require 'base64'
                    Base64.decode64(elements['document/chunk'].text)
                end

            end

        end
    end
end
