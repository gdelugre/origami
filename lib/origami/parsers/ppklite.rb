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

    class PPKLite

        class Parser < Origami::Parser
            def parse(stream) #:nodoc:
                super

                address_book = PPKLite.new(self)
                address_book.header = PPKLite::Header.parse(@data)
                @options[:callback].call(address_book.header)

                loop do
                    break if (object = parse_object).nil?
                    address_book.insert(object)
                end

                address_book.revisions.first.xreftable = parse_xreftable
                address_book.revisions.first.trailer = parse_trailer

                if Origami::OPTIONS[:enable_type_propagation]
                    trailer = address_book.revisions.first.trailer

                    if trailer[:Root].is_a?(Reference)
                        address_book.cast_object(trailer[:Root], PPKLite::Catalog)
                    end

                    propagate_types(address_book)
                end

                address_book
            end
        end
    end
end
