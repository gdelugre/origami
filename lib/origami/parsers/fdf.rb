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

require 'origami/parser'

module Origami

    class FDF
        class Parser < Origami::Parser
            def parse(stream) #:nodoc:
                super(stream)

                fdf = FDF.new(self)
                fdf.header = FDF::Header.parse(@data)
                @options[:callback].call(fdf.header)

                loop do
                    break if (object = parse_object).nil?
                    fdf.insert(object)
                end

                fdf.revisions.first.xreftable = parse_xreftable
                fdf.revisions.first.trailer = parse_trailer

                if Origami::OPTIONS[:enable_type_propagation]
                    trailer = fdf.revisions.first.trailer

                    if trailer[:Root].is_a?(Reference)
                        fdf.cast_object(trailer[:Root], FDF::Catalog)
                    end

                    propagate_types(fdf)
                end

                fdf
            end
        end
    end
end
