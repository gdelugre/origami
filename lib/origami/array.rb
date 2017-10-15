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

    class InvalidArrayObjectError < InvalidObjectError #:nodoc:
    end

    #
    # Class representing an Array Object.
    # Arrays contain a set of Object.
    #
    class Array < ::Array
        include CompoundObject
        using TypeConversion

        TOKENS = %w{ [ ] } #:nodoc:
        @@regexp_open = Regexp.new(WHITESPACES + Regexp.escape(TOKENS.first) + WHITESPACES)
        @@regexp_close = Regexp.new(WHITESPACES + Regexp.escape(TOKENS.last) + WHITESPACES)

        #
        # Creates a new PDF Array Object.
        # _data_:: An array of objects.
        #
        def initialize(data = [], parser = nil, hint_type: nil)
            raise TypeError, "Expected type Array, received #{data.class}." unless data.is_a?(::Array)
            super()

            data.each_with_index do |value, index|
                value = value.to_o

                if Origami::OPTIONS[:enable_type_guessing]
                    index_type = hint_type.is_a?(::Array) ? hint_type[index % hint_type.size] : hint_type
                    if index_type.is_a?(::Array) and not value.is_a?(Reference)
                        index_type = index_type.find {|type| type < value.class }
                    end

                    if index_type.is_a?(Class) and index_type < value.class
                        value = value.cast_to(index_type, parser)
                    end

                    if index_type and parser and Origami::OPTIONS[:enable_type_propagation]
                        if value.is_a?(Reference)
                            parser.defer_type_cast(value, index_type)
                        end
                    end
                end

                self.push(value)
            end
        end

        def pre_build
            self.map!(&:to_o)

            super
        end

        def self.parse(stream, parser = nil, hint_type: nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            offset = scanner.pos
            data = []

            if not scanner.skip(@@regexp_open)
                raise InvalidArrayObjectError, "No token '#{TOKENS.first}' found"
            end

            while scanner.skip(@@regexp_close).nil? do
                type = Object.typeof(scanner)
                raise InvalidArrayObjectError, "Bad embedded object format" if type.nil?

                value = type.parse(scanner, parser)
                data << value
            end

            array = Array.new(data, parser, hint_type: hint_type)
            array.file_offset = offset

            array
        end

        #
        # Converts self into a Ruby array.
        #
        def to_a
            super.map(&:value)
        end
        alias value to_a

        alias each_value each

        def to_s(eol: $/) #:nodoc:
            content = TOKENS.first.dup
            content << self.map {|entry|
                entry = entry.to_o

                case entry
                when Dictionary # Do not indent dictionaries inside of arrays.
                    entry.to_s(indent: 0, eol: eol)
                else
                    entry.to_s(eol: eol)
                end
            }.join(' ')
            content << TOKENS.last

            super(content, eol: eol)
        end

        def +(other)
            a = Origami::Array.new(self.to_a + other.to_a)
            a.no, a.generation = @no, @generation

            a
        end

        def <<(item)
            super link_object(item)
        end

        def push(*items)
            items.each {|item| self << item }
        end

        def []=(index, item)
            super(index, link_object(item))
        end

        def insert(index, *items)
            items.reverse_each do |item|
                super(index, link_object(item))
            end

            self
        end

        def concat(*arys)
            self.push(*arys.flatten)
        end

        #
        # Parameterized Array class with additional typing information.
        # Example: Array.of(Integer)
        #
        def self.of(klass, *klasses, length: nil)
            Class.new(self) do
                const_set('ARRAY_TYPE', (klasses.empty? and not klass.is_a?(::Array)) ? klass : [ klass ].concat(klasses))
                const_set('STATIC_LENGTH', length)

                def initialize(data = [], parser = nil)
                    super(data, parser, hint_type: self.class.const_get('ARRAY_TYPE'))
                end

                def pre_build #:nodoc:
                    do_type_check if Origami::OPTIONS[:enable_type_checking]

                    super
                end

                def self.parse(stream, parser = nil)
                    super(stream, parser, hint_type: const_get('ARRAY_TYPE'))
                end

                def do_type_check #:nodoc:
                    static_length = self.class.const_get('STATIC_LENGTH')
                    array_type = self.class.const_get('ARRAY_TYPE')

                    if static_length and self.length != static_length
                        STDERR.puts "Warning: object #{self.class.name} has unexpected length #{self.length} (should be #{static_length})"
                    end

                    self.each_with_index do |object, index|
                        index_type = array_type.is_a?(::Array) ? array_type[index % array_type.size] : array_type

                        begin
                            object_value = object.solve
                        rescue InvalidReferenceError
                            STDERR.puts "Warning: in object #{self.class}, invalid reference at index #{index}"
                            next
                        end

                        unless object_value.is_a?(index_type)
                            STDERR.puts "Warning: object #{self.class.name || 'Array'} should be composed of #{index_type.name} at index #{index} (got #{object_value.type} instead)"
                        end
                    end
                end
            end
        end
    end

    #
    # Class representing a location on a page or a bounding box.
    #
    class Rectangle < Array.of(Number, length: 4)

        def self.[](coords)
            corners =
                if [ :llx, :lly, :urx, :ury ].all? {|p| coords.include?(p)}
                    coords.values_at(:llx, :lly, :urx, :ury)
                elsif [ :width, :height ].all? {|p| coords.include?(p)}
                    width, height = coords.values_at(:width, :height)
                    x = coords.fetch(:x, 0)
                    y = coords.fetch(:y, 0)
                    [ x, y, x+width, y+height ]
                else
                    raise ArgumentError, "Bad arguments for #{self.class}: #{coords.inspect}"
                end

            unless corners.all? { |corner| corner.is_a?(Numeric) }
                raise TypeError, "All coords must be numbers"
            end

            Rectangle.new(corners)
        end

        def width
            self[2] - self[0]
        end

        def height
            self[3] - self[1]
        end
    end

end
