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
            # The _datasets_ element enclosed XML data content that may have originated from an XFA form and/or
            # may be intended to be consumed by an XFA form.
            #
            class Datasets < XFA::Element
                mime_type 'text/xml'

                class Data < XFA::Element
                    def initialize
                        super('xfa:data')
                    end
                end

                def initialize
                    super("xfa:datasets")

                    add_attribute 'xmlns:xfa', 'http://www.xfa.org/schema/xfa-data/1.0/'
                end
            end

        end
    end
end
