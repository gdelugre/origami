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

        TOKENS = %w{ << >> } #:nodoc:
        @@regexp_open = Regexp.new(WHITESPACES + TOKENS.first + WHITESPACES)
        @@regexp_close = Regexp.new(WHITESPACES + TOKENS.last + WHITESPACES)

        @@type_signatures = {}
        @@type_keys = []

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

            if Origami::OPTIONS[:enable_type_guessing] and not (@@type_keys & hash.keys).empty?
                dict_type = self.guess_type(hash)
            else
                dict_type = self
            end

            # Creates the Dictionary.
            dict = dict_type.new(hash, parser)

            dict.file_offset = offset
            dict
        end

        def to_s(indent: 1, tab: "\t") #:nodoc:
            if indent > 0
                content = TOKENS.first + EOL
                self.each_pair do |key,value|
                    content << tab * indent << key.to_s << ' '
                    content << (value.is_a?(Dictionary) ? value.to_s(indent: indent+1) : value.to_s)
                    content << EOL
                end

                content << tab * (indent - 1) << TOKENS.last
            else
                content = TOKENS.first.dup
                self.each_pair do |key,value|
                    content << "#{key} #{value.is_a?(Dictionary) ? value.to_s(indent: 0) : value.to_s}"
                end
                content << TOKENS.last
            end

            super(content)
        end

        #
        # Note: transform_values should be preferred with Ruby >= 2.4.
        #
        def map!(&b)
            self.each_pair do |k,v|
                self[k] = b.call(v)
            end
        end

        def merge(dict)
            Dictionary.new(super(dict))
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

        def copy
            copy = self.class.new
            self.each_pair do |k,v|
                copy[k] = v.copy
            end

            copy.parent = @parent
            copy.no, copy.generation = @no, @generation
            copy.set_indirect(true) if self.indirect?
            copy.set_document(@document) if self.indirect?

            copy
        end

        def self.add_type_signature(key, value) #:nodoc:
            key, value = key.to_o, value.to_o

            # Inherit the superclass type information.
            if not @@type_signatures.key?(self) and @@type_signatures.key?(self.superclass)
                @@type_signatures[self] = @@type_signatures[self.superclass].dup
            end

            @@type_signatures[self] ||= {}
            @@type_signatures[self][key] = value

            @@type_keys.push(key) unless @@type_keys.include?(key)
        end

        def self.guess_type(hash) #:nodoc:
            best_type = self

            @@type_signatures.each_pair do |klass, keys|
                next unless klass < best_type

                best_type = klass if keys.all? { |k,v| hash[k] == v }
            end

            best_type
        end

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
