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

    class InvalidDictionaryObjectError < InvalidObjectError #:nodoc:
    end

    #
    # Class representing a Dictionary Object.
    # Dictionaries are containers associating a Name to an embedded Object.
    #
    class Dictionary < Hash
        include CompoundObject
        include FieldAccessor
        using TypeConversion
        extend TypeGuessing

        TOKENS = %w{ << >> } #:nodoc:
        @@regexp_open = Regexp.new(WHITESPACES + TOKENS.first + WHITESPACES)
        @@regexp_close = Regexp.new(WHITESPACES + TOKENS.last + WHITESPACES)

        #
        # Creates a new Dictionary.
        # _hash_:: The hash representing the new Dictionary.
        #
        def initialize(hash = {}, parser = nil)
            raise TypeError, "Expected type Hash, received #{hash.class}." unless hash.is_a?(Hash)
            super()

            hash.each_pair do |k,v|
                next if k.nil?

                # Turns the values into Objects.
                key, value = k.to_o, v.to_o

                if Origami::OPTIONS[:enable_type_guessing]
                    hint_type = guess_value_type(key, value)

                    if hint_type.is_a?(Class) and hint_type < value.class
                        value = value.cast_to(hint_type, parser)
                    end

                    if hint_type and parser and Origami::OPTIONS[:enable_type_propagation]
                        if value.is_a?(Reference)
                            parser.defer_type_cast(value, hint_type)
                        end
                    end
                end

                self[key] = value
            end
        end

        def self.parse(stream, parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            offset = scanner.pos

            if scanner.skip(@@regexp_open).nil?
                raise InvalidDictionaryObjectError, "No token '#{TOKENS.first}' found"
            end

            hash = {}
            while scanner.skip(@@regexp_close).nil? do
                key = Name.parse(scanner, parser)

                type = Object.typeof(scanner)
                raise InvalidDictionaryObjectError, "Invalid object for field #{key}" if type.nil?

                value = type.parse(scanner, parser)
                hash[key] = value
            end

            if Origami::OPTIONS[:enable_type_guessing]
                dict_type = self.guess_type(hash)
            else
                dict_type = self
            end

            # Creates the Dictionary.
            dict = dict_type.new(hash, parser)

            dict.file_offset = offset
            dict
        end

        def to_s(indent: 1, tab: "\t", eol: $/) #:nodoc:
            nl = eol
            tab, nl = '', '' if indent == 0

            content = TOKENS.first + nl
            self.each_pair do |key,value|
                content << "#{tab * indent}#{key} "

                content <<
                if value.is_a?(Dictionary)
                    value.to_s(eol: eol, indent: (indent == 0) ? 0 : indent + 1)
                else
                    value.to_s(eol: eol)
                end

                content << nl
            end

            content << tab * (indent - 1) if indent > 0
            content << TOKENS.last

            super(content, eol: eol)
        end

        #
        # Returns a new Dictionary object with values modified by given block.
        #
        def transform_values(&b)
            self.class.new self.map { |k, v|
                [ k.to_sym, b.call(v) ]
            }.to_h
        end

        #
        # Modifies the values of the Dictionary, leaving keys unchanged.
        #
        def transform_values!(&b)
            self.each_pair do |k, v|
                self[k] = b.call(unlink_object(v))
            end
        end

        #
        # Merges the content of the Dictionary with another Dictionary.
        #
        def merge(dict)
            self.class.new(super(dict))
        end

        def []=(key,val)
            unless key.is_a?(Symbol) or key.is_a?(Name)
                raise TypeError, "Expecting a Name for a Dictionary entry, found #{key.class} instead."
            end

            if val.nil?
                self.delete(key)
                return
            end

            super(link_object(key), link_object(val))
        end

        def [](key)
            super(key.to_o)
        end

        alias key? include?
        alias has_key? key?

        def to_h
            Hash[self.to_a.map!{|k, v| [ k.value, v.value ]}]
        end
        alias value to_h

        def self.hint_type(_name); nil end #:nodoc:

        private

        def guess_value_type(key, value)
            hint_type = self.class.hint_type(key.value)
            if hint_type.is_a?(::Array) and not value.is_a?(Reference) # Choose best match
                hint_type = hint_type.find {|type| type < value.class }
            end

            hint_type
        end
    end

end
