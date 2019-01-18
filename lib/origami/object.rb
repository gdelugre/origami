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

require 'set'

#
# Module for parsing/generating PDF files.
#
module Origami

    #
    # Provides refinements for standard Ruby types.
    # Allows to convert native types to their associated Origami::Object types using method #to_o.
    #
    module TypeConversion
        refine ::Integer do
            def to_o
                Origami::Integer.new(self)
            end
        end

        refine ::Array do
            def to_o
                Origami::Array.new(self)
            end
        end

        refine ::Float do
            def to_o
                Origami::Real.new(self)
            end
        end

        refine ::Hash do
            def to_o
                Origami::Dictionary.new(self)
            end
        end

        refine ::TrueClass do
            def to_o
                Origami::Boolean.new(true)
            end
        end

        refine ::FalseClass do
            def to_o
                Origami::Boolean.new(false)
            end
        end

        refine ::NilClass do
            def to_o
                Origami::Null.new
            end
        end

        refine ::Symbol do
            def to_o
                Origami::Name.new(self)
            end
        end

        refine ::String do
            def to_o
                Origami::LiteralString.new(self)
            end
        end
    end

    module TypeGuessing
        using TypeConversion

        def guess_type(hash)
            return self if (@@type_keys & hash.keys).empty?
            best_match = self

            @@signatures.each_pair do |klass, keys|
                next unless klass < best_match

                best_match = klass if keys.all? {|k,v| v.is_a?(Set) ? v.include?(hash[k]) : hash[k] == v }
            end

            best_match
        end

        private

        def add_type_signature(**key_vals)
            @@signatures ||= {}
            @@type_keys ||= Set.new

            # Inherit the superclass type information.
            if not @@signatures.key?(self) and @@signatures.key?(self.superclass)
                @@signatures[self] = @@signatures[self.superclass].dup
            end

            @@signatures[self] ||= {}

            key_vals.each_pair do |key, value|
                key, value = key.to_o, value.to_o

                if @@signatures[self].key?(key)
                    if @@signatures[self][key].is_a?(Set)
                        @@signatures[self][key].add(value)
                    elsif @@signatures[self][key] != value
                        @@signatures[self][key] = Set.new.add(@@signatures[self][key]).add(value)
                    end
                else
                    @@signatures[self][key] = value
                end

                @@type_keys.add(key)
            end
        end
    end

    #
    # Provides an easier syntax for field access.
    # The object must have the defined the methods #[] and #[]=.
    #
    # Once included, object.Field will automatically resolve to object[:Field].
    # References are automatically followed.
    #
    module FieldAccessor
        def method_missing(field, *args)
            raise NoMethodError, "No method `#{field}' for #{self.class}" unless field =~ /^[[:upper:]]/

            if field[-1] == '='
                self[field[0..-2].to_sym] = args.first
            else
                object = self[field]
                object.is_a?(Reference) ? object.solve : object
            end
        end

        def respond_to_missing?(field, *)
            not (field =~ /^[[:upper:]]/).nil? or super
        end
    end

    #
    # Mixin' module for objects which can store their options into an inner Dictionary.
    #
    module StandardObject #:nodoc:
        DEFAULT_ATTRIBUTES = { :Type => Object, :Version => "1.2" } #:nodoc:

        def self.included(receiver) #:nodoc:
            receiver.instance_variable_set(:@fields, Hash.new(DEFAULT_ATTRIBUTES))
            receiver.extend(ClassMethods)
        end

        module ClassMethods #:nodoc:all
            include TypeGuessing

            def inherited(subclass)
                subclass.instance_variable_set(:@fields, Hash[@fields.map{|name, attributes| [name, attributes.clone]}])
            end

            def fields
                @fields
            end

            #
            # Define a new field with given attributes.
            #
            def field(name, attributes)
                if attributes[:Required] and attributes.key?(:Default) and attributes[:Type] == Name
                    signature = {}
                    signature[name] = attributes[:Default]

                    add_type_signature(**signature)
                end

                if @fields.key?(name)
                    @fields[name].merge! attributes
                else
                    @fields[name] = attributes
                end

                define_field_methods(name)
            end

            #
            # Returns an array of required fields for the current Object.
            #
            def required_fields
                fields = []
                @fields.each_pair do |name, attributes|
                    fields << name if attributes[:Required] == true
                end

                fields
            end

            #
            # Returns the expected type for a field name.
            #
            def hint_type(name)
                @fields[name][:Type] if @fields.key?(name)
            end

            private

            def define_field_methods(field) #:nodoc:

                #
                # Getter method.
                #
                getter = field.to_s
                remove_method(getter) rescue NameError
                define_method(getter) do
                    obj = self[field]
                    obj.is_a?(Reference) ? obj.solve : obj
                end

                #
                # Setter method.
                #
                setter = field.to_s + "="
                remove_method(setter) rescue NameError
                define_method(setter) do |value|
                    self[field] = value
                end

                # Setter method returning self.
                setter_self = "set" + field.to_s
                remove_method(setter_self) rescue NameError
                define_method(setter_self) do |value|
                    self[field] = value
                    self
                end
            end
        end

        def pre_build #:nodoc:
            set_default_values
            do_type_check if Origami::OPTIONS[:enable_type_checking] == true

            super
        end

        #
        # Returns the version and level required by the current Object.
        #
        def version_required #:nodoc:
            max = [ "1.0", 0 ]

            self.each_key do |field|
                attributes = self.class.fields[field.value]
                if attributes.nil?
                    STDERR.puts "Warning: object #{self.class} has undocumented field #{field.value}"
                    next
                end

                version = attributes[:Version] || '1.0'
                level = attributes[:ExtensionLevel] || 0
                current = [ version, level ]

                max = [ max, current, self[field.value].version_required ].max
            end

            max
        end

        private

        def set_default_value(field) #:nodoc:
            if self.class.fields[field][:Default]
                self[field] = self.class.fields[field][:Default]
                self[field].pre_build
            end
        end

        def set_default_values #:nodoc:
            self.class.required_fields.each do |field|
                set_default_value(field) unless self.key?(field)
            end
        end

        def do_type_check #:nodoc:
            self.class.fields.each_pair do |field, attributes|
                next if self[field].nil? or attributes[:Type].nil?

                begin
                    field_value = self[field].solve
                rescue InvalidReferenceError
                    STDERR.puts "Warning: in object #{self.class}, field `#{field}' is an invalid reference (#{self[field]})"
                    next
                end

                types = attributes[:Type].is_a?(::Array) ? attributes[:Type] : [ attributes[:Type] ]

                unless types.any? {|type| not type.is_a?(Class) or field_value.is_a?(type.native_type)}
                    STDERR.puts "Warning: in object #{self.class}, field `#{field}' has unexpected type #{field_value.class}"
                end

                if attributes.key?(:Assert) and not (attributes[:Assert] === field_value)
                    STDERR.puts "Warning: assertion failed for field `#{field}' in object #{self.class}"
                end
            end
        end
    end

    class InvalidObjectError < Error #:nodoc:
    end

    class UnterminatedObjectError < Error #:nodoc:
        attr_reader :obj

        def initialize(msg,obj)
            super(msg)
            @obj = obj
        end
    end

    WHITESPACES = "([ \\f\\t\\r\\n\\0]|%[^\\n\\r]*(\\r\\n|\\r|\\n))*" #:nodoc:
    WHITECHARS_NORET = "[ \\f\\t\\0]*" #:nodoc:
    WHITECHARS = "[ \\f\\t\\r\\n\\0]*" #:nodoc:
    REGEXP_WHITESPACES = Regexp.new(WHITESPACES) #:nodoc:

    #
    # Parent module representing a PDF Object.
    # PDF specification declares a set of primitive object types :
    # * Null
    # * Boolean
    # * Integer
    # * Real
    # * Name
    # * String
    # * Array
    # * Dictionary
    # * Stream
    #
    module Object

        TOKENS = %w{ obj endobj } #:nodoc:
        @@regexp_obj = Regexp.new(WHITESPACES + "(?<no>\\d+)" + WHITESPACES + "(?<gen>\\d+)" +
                                  WHITESPACES + TOKENS.first + WHITESPACES)
        @@regexp_endobj = Regexp.new(WHITESPACES + TOKENS.last + WHITESPACES)

        attr_accessor :no, :generation, :file_offset, :objstm_offset
        attr_accessor :parent

        #
        # Modules or classes including this module are considered native types.
        #
        def self.included(base)
            base.class_variable_set(:@@native_type, base)
            base.extend(ClassMethods)
        end

        module ClassMethods
            # Returns the native type of the derived class or module.
            def native_type
                self.class_variable_get(:@@native_type)
            end

            private

            # Propagate native type to submodules.
            def included(klass)
                klass.class_variable_set(:@@native_type, self)
                klass.extend(ClassMethods)
            end
        end

        #
        # Returns the native type of the Object.
        #
        def native_type
            self.class.native_type
        end

        #
        # Creates a new PDF Object.
        #
        def initialize(*cons)
            @indirect = false
            @no, @generation = 0, 0
            @document = nil
            @parent = nil
            @file_offset = nil

            super(*cons) unless cons.empty?
        end

        #
        # Sets whether the object is indirect or not.
        # Indirect objects are allocated numbers at build time.
        #
        def set_indirect(bool)
            unless bool == true or bool == false
                raise TypeError, "The argument must be boolean"
            end

            if bool == false
                @no = @generation = 0
                @document = nil
                @file_offset = nil
            end

            @indirect = bool
            self
        end

        #
        # Generic method called just before the object is finalized.
        # At this time, no number nor generation allocation has yet been done.
        #
        def pre_build
            self
        end

        #
        # Generic method called just after the object is finalized.
        # At this time, any indirect object has its own number and generation identifier.
        #
        def post_build
            self
        end

        #
        # Returns whether the objects is indirect, which means that it is not embedded into another object.
        #
        def indirect?
            @indirect
        end

        #
        # Returns whether an object number exists for this object.
        #
        def numbered?
            @no > 0
        end

        #
        # Deep copy of an object.
        #
        def copy
            saved_doc = @document
            saved_parent = @parent

            @document = @parent = nil # do not process parent object and document in the copy

            # Perform the recursive copy (quite dirty).
            copyobj = Marshal.load(Marshal.dump(self))

            # restore saved values
            @document = saved_doc
            @parent = saved_parent

            copyobj.set_document(saved_doc) if copyobj.indirect?
            copyobj.parent = parent

            copyobj
        end

        #
        # Casts an object to a new type.
        #
        def cast_to(type, parser = nil)
            assert_cast_type(type)

            cast = type.new(self.copy, parser)
            cast.file_offset = @file_offset

            transfer_attributes(cast)
        end

        #
        # Returns an indirect reference to this object.
        #
        def reference
            raise InvalidObjectError, "Cannot reference a direct object" unless self.indirect?

            ref = Reference.new(@no, @generation)
            ref.parent = self

            ref
        end

        #
        # Returns an array of references pointing to the current object.
        #
        def xrefs
            raise InvalidObjectError, "Cannot find xrefs to a direct object" unless self.indirect?
            raise InvalidObjectError, "Not attached to any document" if self.document.nil?

            @document.each_object(compressed: true)
                     .flat_map { |object|
                        case object
                        when Stream
                            object.dictionary.xref_cache[self.reference]
                        when ObjectCache
                            object.xref_cache[self.reference]
                        end
                     }
                     .compact!
        end

        #
        # Creates an exportable version of current object.
        # The exportable version is a copy of _self_ with solved references, no owning PDF and no parent.
        # References to Catalog or PageTreeNode objects have been destroyed.
        #
        # When exported, an object can be moved into another document without hassle.
        #
        def export
            exported_obj = self.logicalize
            exported_obj.no = exported_obj.generation = 0
            exported_obj.set_document(nil) if exported_obj.indirect?
            exported_obj.parent = nil
            exported_obj.xref_cache.clear

            exported_obj
        end

        #
        # Returns a logicalized copy of _self_.
        # See logicalize!
        #
        def logicalize #:nodoc:
            self.copy.logicalize!
        end

        #
        # Transforms recursively every references to the copy of their respective object.
        # Catalog and PageTreeNode objects are excluded to limit the recursion.
        #
        def logicalize! #:nodoc:
            resolve_all_references(self)
        end

        #
        # Returns the indirect object which contains this object.
        # If the current object is already indirect, returns self.
        #
        def indirect_parent
            obj = self
            obj = obj.parent until obj.indirect?

            obj
        end

        #
        # Returns self.
        #
        def to_o
            self
        end

        #
        # Returns self.
        #
        def solve
            self
        end

        #
        # Returns the PDF which the object belongs to.
        #
        def document
            if self.indirect? then @document
            else
                @parent.document unless @parent.nil?
            end
        end

        def set_document(doc)
            raise InvalidObjectError, "You cannot set the document of a direct object" unless self.indirect?

            @document = doc
        end

        class << self

            def typeof(stream) #:nodoc:
                scanner = Parser.init_scanner(stream)
                scanner.skip(REGEXP_WHITESPACES)

                case scanner.peek(1)
                when '/' then return Name
                when '<'
                    return (scanner.peek(2) == '<<') ? Stream : HexaString
                when '(' then return LiteralString
                when '[' then return Origami::Array
                when 'n' then
                    return Null if scanner.peek(4) == 'null'
                when 't' then
                    return Boolean if scanner.peek(4) == 'true'
                when 'f' then
                    return Boolean if scanner.peek(5) == 'false'
                else
                    if scanner.check(Reference::REGEXP_TOKEN) then return Reference
                    elsif scanner.check(Real::REGEXP_TOKEN) then return Real
                    elsif scanner.check(Integer::REGEXP_TOKEN) then return Integer
                    else
                        nil
                    end
                end

                nil
            end

            def parse(stream, parser = nil) #:nodoc:
                scanner = Parser.init_scanner(stream)
                offset = scanner.pos

                #
                # End of body ?
                #
                return nil if scanner.match?(/xref/) or scanner.match?(/trailer/) or scanner.match?(/startxref/)

                if scanner.scan(@@regexp_obj).nil?
                    raise InvalidObjectError, "Object shall begin with '%d %d obj' statement"
                end

                no = scanner['no'].to_i
                gen = scanner['gen'].to_i

                type = typeof(scanner)
                if type.nil?
                    raise InvalidObjectError, "Cannot determine object (no:#{no},gen:#{gen}) type"
                end

                begin
                    new_obj = type.parse(scanner, parser)
                rescue
                    raise InvalidObjectError, "Failed to parse object (no:#{no},gen:#{gen})\n\t -> [#{$!.class}] #{$!.message}"
                end

                new_obj.set_indirect(true)
                new_obj.no = no
                new_obj.generation = gen
                new_obj.file_offset = offset

                if scanner.skip(@@regexp_endobj).nil?
                    raise UnterminatedObjectError.new("Object shall end with 'endobj' statement", new_obj)
                end

                new_obj
            end

            def skip_until_next_obj(scanner) #:nodoc:
                [ @@regexp_obj, /xref/, /trailer/, /startxref/ ].each do |re|
                    if scanner.scan_until(re)
                        scanner.pos -= scanner.matched_size
                        return true
                    end
                end

                false
            end
        end

        def version_required #:nodoc:
            [ '1.0', 0 ]
        end

        #
        # Returns the symbol type of this Object.
        #
        def type
            name = (self.class.name or self.class.superclass.name or self.native_type.name)

            name.split("::").last.to_sym
        end

        #
        # Outputs this object into PDF code.
        # _data_:: The object data.
        #
        def to_s(data, eol: $/)
            content = ""
            content << "#{no} #{generation} #{TOKENS.first}" << eol if indirect? and numbered?
            content << data
            content << eol << TOKENS.last << eol if indirect? and numbered?

            content.force_encoding('binary')
        end
        alias output to_s

        private

        #
        # Raises a TypeError exception if the current object is not castable to the provided type.
        #
        def assert_cast_type(type) #:nodoc:
            if type.native_type != self.native_type
                raise TypeError, "Incompatible cast from #{self.class} to #{type}"
            end
        end

        #
        # Copy the attributes of the current object to another object.
        # Copied attributes do not include the file offset.
        #
        def transfer_attributes(target)
            target.no, target.generation = @no, @generation
            target.parent = @parent
            if self.indirect?
                target.set_indirect(true)
                target.set_document(@document)
            end

            target
        end

        #
        # Replace all references of an object by their actual object value.
        #
        def resolve_all_references(obj, browsed: [], cache: {})
            return obj if browsed.include?(obj)
            browsed.push(obj)

            if obj.is_a?(ObjectStream)
                obj.each do |subobj|
                    resolve_all_references(subobj, browsed: browsed, cache: cache)
                end
            end

            if obj.is_a?(Stream)
                resolve_all_references(obj.dictionary, browsed: browsed, cache: cache)
            end

            if obj.is_a?(CompoundObject)
                obj.update_values! do |subobj|
                    if subobj.is_a?(Reference)
                        subobj = (cache[subobj] ||= subobj.solve.copy)
                        subobj.no = subobj.generation = 0
                        subobj.parent = obj
                    end

                    resolve_all_references(subobj, browsed: browsed, cache: cache)
                end
            end

            obj
        end
    end

end
