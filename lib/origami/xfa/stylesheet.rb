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
            # The _stylesheet_ packet encloses a single XSLT stylesheet.
            #
            class StyleSheet < XFA::Element
                mime_type 'text/css'

                def initialize(id)
                    super("xsl:stylesheet")

                    add_attribute 'version', '1.0'
                    add_attribute 'xmlns:xsl', 'http://www.w3.org/1999/XSL/Transform'
                    add_attribute 'id', id.to_s
                end
            end

        end
    end
end
