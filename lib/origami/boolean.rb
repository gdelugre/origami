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

    class InvalidBooleanObjectError < InvalidObjectError #:nodoc:
    end

    #
    # Class representing a Boolean Object.
    # A Boolean Object can be *true* or *false*.
    #
    class Boolean
        include Origami::Object

        TOKENS = %w{ true false } #:nodoc:
        @@regexp = Regexp.new(WHITESPACES + "(?<value>#{Regexp.union(TOKENS)})")

        #
        # Creates a new Boolean value.
        # _value_:: *true* or *false*.
        #
        def initialize(value)
            unless value.is_a?(TrueClass) or value.is_a?(FalseClass)
                raise TypeError, "Expected type TrueClass or FalseClass, received #{value.class}."
            end

            super()

            @value = (value == true)
        end

        def to_s(eol: $/) #:nodoc:
            super(@value.to_s, eol: eol)
        end

        def self.parse(stream, _parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            offset = scanner.pos

            if scanner.scan(@@regexp).nil?
                raise InvalidBooleanObjectError
            end

            value = (scanner['value'] == "true")

            bool = Boolean.new(value)
            bool.file_offset = offset

            bool
        end

        #
        # Converts self into a Ruby boolean, that is TrueClass or FalseClass instance.
        #
        def value
            @value
        end

        def false?
            @value == false
        end

        def true?
            @value == true
        end

        def ==(bool)
            @value == bool
        end
    end

end
