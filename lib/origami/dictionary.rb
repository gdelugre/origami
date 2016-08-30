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
        include Origami::Object
        include FieldAccessor
        using TypeConversion

        TOKENS = %w{ << >> } #:nodoc:
        @@regexp_open = Regexp.new(WHITESPACES + TOKENS.first + WHITESPACES)
        @@regexp_close = Regexp.new(WHITESPACES + TOKENS.last + WHITESPACES)

        @@cast_fingerprints = {}
        @@cast_keys = []

        attr_reader :strings_cache, :names_cache, :xref_cache

        #
        # Creates a new Dictionary.
        # _hash_:: The hash representing the new Dictionary.
        #
        def initialize(hash = {}, parser = nil)
            raise TypeError, "Expected type Hash, received #{hash.class}." unless hash.is_a?(Hash)
            super()

            @strings_cache = []
            @names_cache = []
            @xref_cache = {}

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

                # Cache keys and values for fast search.
                cache_key(key)
                cache_value(value)

                self[key] = value
            end
        end

        def self.parse(stream, parser = nil) #:nodoc:
            offset = stream.pos

            if stream.skip(@@regexp_open).nil?
                raise InvalidDictionaryObjectError, "No token '#{TOKENS.first}' found"
            end

            hash = {}
            while stream.skip(@@regexp_close).nil? do
                key = Name.parse(stream, parser)

                type = Object.typeof(stream)
                raise InvalidDictionaryObjectError, "Invalid object for field #{key}" if type.nil?

                value = type.parse(stream, parser)
                hash[key] = value
            end

            if Origami::OPTIONS[:enable_type_guessing] and not (@@cast_keys & hash.keys).empty?
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
                fail "Expecting a Name for a Dictionary entry, found #{key.class} instead."
            end

            key = key.to_o
            if val.nil?
                delete(key)
                return
            end

            val = val.to_o
            super(key,val)

            key.parent = self
            val.parent = self unless val.indirect? or val.parent.equal?(self)

            val
        end

        def [](key)
            super(key.to_o)
        end

        def key?(key)
            super(key.to_o)
        end
        alias include? key?
        alias has_key? key?

        def delete(key)
            super(key.to_o)
        end

        def cast_to(type, parser = nil)
            super(type)

            cast = type.new(self.copy, parser)
            cast.parent = self.parent
            cast.no, cast.generation = self.no, self.generation
            if self.indirect?
                cast.set_indirect(true)
                cast.set_document(self.document)
                cast.file_offset = self.file_offset # cast can replace self
            end

            cast
        end

        alias each each_value

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

        def self.native_type; Dictionary end

        def self.add_type_info(klass, key, value) #:nodoc:
            raise TypeError, "Invalid class #{klass}" unless klass.is_a?(Class) and klass < Dictionary

            key, value = key.to_o, value.to_o

            # Inherit the superclass type information.
            if not @@cast_fingerprints.key?(klass) and @@cast_fingerprints.key?(klass.superclass)
                @@cast_fingerprints[klass] = @@cast_fingerprints[klass.superclass].dup
            end

            @@cast_fingerprints[klass] ||= {}
            @@cast_fingerprints[klass][key] = value

            @@cast_keys.push(key) unless @@cast_keys.include?(key)
        end

        def self.guess_type(hash) #:nodoc:
            best_type = self

            @@cast_fingerprints.each_pair do |klass, keys|
                next unless klass < best_type

                best_type = klass if keys.all? { |k,v| hash[k] == v }
            end

            best_type
        end

        def self.hint_type(_name); nil end #:nodoc:

        private

        def cache_key(key)
            @names_cache.push(key)
        end

        def cache_value(value)
            case value
            when String then @strings_cache.push(value)
            when Name then @names_cache.push(value)
            when Reference then
                (@xref_cache[value] ||= []).push(self)
            when Dictionary, Array
                @strings_cache.concat(value.strings_cache)
                @names_cache.concat(value.names_cache)
                @xref_cache.update(value.xref_cache) do |_ref, cache1, cache2|
                    cache1.concat(cache2)
                end

                value.strings_cache.clear
                value.names_cache.clear
                value.xref_cache.clear
            end
        end

        def guess_value_type(key, value)
            hint_type = self.class.hint_type(key.value)
            if hint_type.is_a?(::Array) and not value.is_a?(Reference) # Choose best match
                hint_type = hint_type.find {|type| type < value.class }
            end

            hint_type
        end
    end

end
