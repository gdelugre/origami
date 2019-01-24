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

    REGULARCHARS = "([^ \\t\\r\\n\\0\\[\\]<>()%\\/]|#[a-fA-F0-9][a-fA-F0-9])*" #:nodoc:

    class InvalidNameObjectError < InvalidObjectError #:nodoc:
    end

    #
    # Class representing a Name Object.
    # Name objects are strings which identify some PDF file inner structures.
    #
    class Name
        include Origami::Object
        include Comparable

        TOKENS = %w{ / } #:nodoc:

        @@regexp = Regexp.new(WHITESPACES + TOKENS.first + "(?<name>#{REGULARCHARS})" + WHITESPACES) #:nodoc

        #
        # Creates a new Name.
        # _name_:: A symbol representing the new Name value.
        #
        def initialize(name = "")
            unless name.is_a?(Symbol) or name.is_a?(::String)
                raise TypeError, "Expected type Symbol or String, received #{name.class}."
            end

            @value = name.to_s

            super()
        end

        def value
            @value.to_sym
        end
        alias to_sym value

        def <=>(name)
            return unless name.is_a?(Name)

            self.value <=> name.value
        end

        def ==(object) #:nodoc:
            self.eql?(object) or @value.to_sym == object
        end

        def eql?(object) #:nodoc:
            object.is_a?(Name) and self.value.eql?(object.value)
        end

        def hash #:nodoc:
            @value.hash
        end

        def to_s(eol: $/) #:nodoc:
            super(TOKENS.first + Name.expand(@value), eol: eol)
        end

        def self.parse(stream, _parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            offset = scanner.pos

            name =
                if scanner.scan(@@regexp).nil?
                    raise InvalidNameObjectError, "Bad name format"
                else
                    value = scanner['name']

                    Name.new(value.include?('#') ? contract(value) : value)
                end

            name.file_offset = offset

            name
        end

        def self.contract(name) #:nodoc:
            i = 0
            name = name.dup

            while i < name.length
                if name[i] == "#"
                    digits = name[i+1, 2]

                    unless digits =~ /^[A-Za-z0-9]{2}$/
                        raise InvalidNameObjectError, "Irregular use of # token"
                    end

                    char = digits.hex.chr

                    if char == "\0"
                        raise InvalidNameObjectError, "Null byte forbidden inside name definition"
                    end

                    name[i, 3] = char
                end

                i = i + 1
            end

            name
        end

        def self.expand(name) #:nodoc:
            forbiddenchars = /[ #\t\r\n\0\[\]<>()%\/]/

            name.gsub(forbiddenchars) do |c|
                "#" + c.ord.to_s(16).rjust(2,"0")
            end
        end
    end

end
