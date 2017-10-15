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

    class InvalidNullObjectError < InvalidObjectError #:nodoc:
    end

    #
    # Class representing  Null Object.
    #
    class Null
        include Origami::Object

        TOKENS = %w{ null } #:nodoc:
        @@regexp = Regexp.new(WHITESPACES + TOKENS.first)

        def initialize
            super
        end

        def self.parse(stream, _parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            offset = scanner.pos

            if scanner.skip(@@regexp).nil?
                raise InvalidNullObjectError
            end

            null = Null.new
            null.file_offset = offset

            null
        end

        #
        # Returns *nil*.
        #
        def value
            nil
        end

        def to_s(eol: $/) #:nodoc:
            super(TOKENS.first, eol: eol)
        end
    end

end
