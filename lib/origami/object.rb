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

#
# Module for parsing/generating PDF files.
#
module Origami

    module TypeConversion

        refine ::Bignum do
            def to_o
                Origami::Integer.new(self)
            end
        end

        refine ::Fixnum do
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

    #
    # Common Exception class for Origami errors.
    #
    class Error < StandardError
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

            def inherited(subclass)
                subclass.instance_variable_set(:@fields, Hash[@fields.map{|name, attributes| [name, attributes.clone]}])
            end

            def fields
                @fields
            end

            def field(name, attributes)
                if attributes[:Required] == true and attributes.has_key?(:Default) and attributes[:Type] == Name
                    self.add_type_info(self, name, attributes[:Default])
                end

                if @fields.has_key?(name)
                    @fields[name].merge! attributes
                else
                    @fields[name] = attributes
                end

                define_field_methods(name)
            end

            def define_field_methods(field)

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

            def hint_type(name)
                if @fields.has_key?(name)
                    @fields[name][:Type]
                end
            end
        end

        def pre_build #:nodoc:
            set_default_values
            do_type_check if Origami::OPTIONS[:enable_type_checking] == true

            super
        end

        #
        # Check if an attribute is set in the current Object.
        # _attr_:: The attribute name.
        #
        def has_field? (field)
            not self[field].nil?
        end

        #
        # Returns the version and level required by the current Object.
        #
        def version_required #:nodoc:
            max = [ 1.0, 0 ]

            self.each_key do |field|
                attributes = self.class.fields[field.value]
                if attributes.nil?
                    STDERR.puts "Warning: object #{self.class} has undocumented field #{field.value}"
                    next
                end

                current_version = attributes.has_key?(:Version) ? attributes[:Version].to_f : 0
                current_level = attributes[:ExtensionLevel] || 0
                current = [ current_version, current_level ]

                max = current if (current <=> max) > 0

                sub = self[field.value].version_required
                max = sub if (sub <=> max) > 0
            end

            max
        end

        def set_default_value(field) #:nodoc:
            if self.class.fields[field][:Default]
                self[field] = self.class.fields[field][:Default]
                self[field].pre_build
            end
        end

        def set_default_values #:nodoc:
            self.class.required_fields.each do |field|
                set_default_value(field) unless has_field?(field)
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

    WHITESPACES = "([ \\f\\t\\r\\n\\0]|%[^\\n]*\\n)*" #:nodoc:
    WHITECHARS_NORET = "[ \\f\\t\\0]*" #:nodoc:
    EOL = "\r\n" #:nodoc:
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
        # Creates a new PDF Object.
        #
        def initialize(*cons)
            @indirect = false
            @no, @generation = 0, 0
            @document = nil
            @parent = nil

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
        # Compare two objects from their respective numbers.
        #
        def <=>(obj)
            [@no, @generation] <=> [obj.no, obj.generation]
        end

        #
        # Returns whether the objects is indirect, which means that it is not embedded into another object.
        #
        def indirect?
            @indirect
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
        # Returns an indirect reference to this object, or a Null object is this object is not indirect.
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
                        when Dictionary, Array
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

            resolve_all_references = -> (obj, browsed = [], ref_cache = {}) do
                return if browsed.include?(obj)
                browsed.push(obj)

                if obj.is_a?(ObjectStream)
                    obj.each do |subobj|
                        resolve_all_references[subobj, browsed, ref_cache]
                    end
                end

                if obj.is_a?(Dictionary) or obj.is_a?(Array)
                    obj.map! do |subobj|
                        if subobj.is_a?(Reference)
                            new_obj =
                                if ref_cache.has_key?(subobj)
                                    ref_cache[subobj]
                                else
                                    ref_cache[subobj] = subobj.solve.copy
                                end
                            new_obj.no = new_obj.generation = 0
                            new_obj.parent = obj

                            new_obj unless new_obj.is_a?(Catalog) or new_obj.is_a?(PageTreeNode)
                        else
                            subobj
                        end
                    end

                    obj.each do |subobj|
                        resolve_all_references[subobj, browsed, ref_cache]
                    end

                elsif obj.is_a?(Stream)
                    resolve_all_references[obj.dictionary, browsed, ref_cache]
                end
            end

            resolve_all_references[self]
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

            def typeof(stream, noref = false) #:nodoc:
                stream.skip(REGEXP_WHITESPACES)

                case stream.peek(1)
                when '/' then return Name
                when '<'
                    return (stream.peek(2) == '<<') ? Stream : HexaString
                when '(' then return LiteralString
                when '[' then return Origami::Array
                when 'n' then
                    return Null if stream.peek(4) == 'null'
                when 't' then
                    return Boolean if stream.peek(4) == 'true'
                when 'f' then
                    return Boolean if stream.peek(5) == 'false'
                else
                    if not noref and stream.check(Reference::REGEXP_TOKEN) then return Reference
                    elsif stream.check(Real::REGEXP_TOKEN) then return Real
                    elsif stream.check(Integer::REGEXP_TOKEN) then return Integer
                    else
                        nil
                    end
                end

                nil
            end

            def parse(stream, parser = nil) #:nodoc:
                offset = stream.pos

                #
                # End of body ?
                #
                return nil if stream.match?(/xref/) or stream.match?(/trailer/) or stream.match?(/startxref/)

                if stream.scan(@@regexp_obj).nil?
                  raise InvalidObjectError,
                    "Object shall begin with '%d %d obj' statement"
                end

                no = stream['no'].to_i
                gen = stream['gen'].to_i

                type = typeof(stream)
                if type.nil?
                    raise InvalidObjectError,
                            "Cannot determine object (no:#{no},gen:#{gen}) type"
                end

                begin
                    new_obj = type.parse(stream, parser)
                rescue
                    raise InvalidObjectError,
                            "Failed to parse object (no:#{no},gen:#{gen})\n\t -> [#{$!.class}] #{$!.message}"
                end

                new_obj.set_indirect(true)
                new_obj.no = no
                new_obj.generation = gen
                new_obj.file_offset = offset

                if stream.skip(@@regexp_endobj).nil?
                    raise UnterminatedObjectError.new("Object shall end with 'endobj' statement", new_obj)
                end

                new_obj
            end

            def skip_until_next_obj(stream) #:nodoc:
                [ @@regexp_obj, /xref/, /trailer/, /startxref/ ].each do |re|
                    if stream.scan_until(re)
                        stream.pos -= stream.matched_size
                        return true
                    end
                end

                false
            end
        end

        def version_required #:nodoc:
            [ 1.0, 0 ]
        end

        #
        # Returns the symbol type of this Object.
        #
        def type
            name = (self.class.name or self.class.superclass.name or self.native_type.name)

            name.split("::").last.to_sym
        end

        def self.native_type; Origami::Object end #:nodoc:

        #
        # Returns the native PDF type of this Object.
        #
        def native_type
          self.class.native_type
        end

        def cast_to(type, _parser = nil) #:nodoc:
            if type.native_type != self.native_type
                raise TypeError, "Incompatible cast from #{self.class} to #{type}"
            end

            self
        end

        #
        # Outputs this object into PDF code.
        # _data_:: The object data.
        #
        def to_s(data)
            content = ""
            content << "#{no} #{generation} #{TOKENS.first}" << EOL if self.indirect?
            content << data
            content << EOL << TOKENS.last << EOL if self.indirect?

            content.force_encoding('binary')
        end

        alias output to_s
    end

end
