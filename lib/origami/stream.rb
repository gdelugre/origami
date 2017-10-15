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

require 'strscan'

module Origami

    class InvalidStreamObjectError < InvalidObjectError #:nodoc:
    end

    # Forward declaration.
    class FileSpec < Dictionary; end

    #
    # Class representing a PDF Stream Object.
    # Streams can be used to hold any kind of data, especially binary data.
    #
    class Stream
        include Origami::Object
        include StandardObject
        include FieldAccessor
        include Enumerable
        extend TypeGuessing

        TOKENS = [ "stream" + WHITECHARS_NORET + "(\\r\\n|\\r|\\n)" , "endstream" ] #:nodoc:

        @@regexp_open = Regexp.new(WHITESPACES + TOKENS.first)
        @@regexp_close = Regexp.new(TOKENS.last)

        #
        # Actually only 5 first ones are implemented,
        # other ones are mainly about image data processing (JPEG, JPEG2000 ...)
        #
        DEFINED_FILTERS = %i[
          ASCIIHexDecode
          ASCII85Decode
          LZWDecode
          FlateDecode
          RunLengthDecode

          CCITTFaxDecode
          JBIG2Decode
          DCTDecode
          JPXDecode

          AHx
          A85
          LZW
          Fl
          RL
          CCF
          DCT
        ]

        attr_reader :dictionary

        field   :Length,          :Type => Integer, :Required => true
        field   :Filter,          :Type => [ Name, Array.of(Name) ]
        field   :DecodeParms,     :Type => [ Dictionary, Array.of(Dictionary) ]
        field   :F,               :Type => FileSpec, :Version => "1.2"
        field   :FFilter,         :Type => [ Name, Array.of(Name) ], :Version => "1.2"
        field   :FDecodeParms,    :Type => [ Dictionary, Array.of(Dictionary) ], :Version => "1.2"
        field   :DL,              :Type => Integer, :Version => "1.5"

        #
        # Creates a new PDF Stream.
        # _data_:: The Stream uncompressed data.
        # _dictionary_:: A hash representing the Stream attributes.
        #
        def initialize(data = "", dictionary = {})
            super()

            set_indirect(true)

            @encoded_data = nil
            @dictionary, @data = Dictionary.new(dictionary), data
            @dictionary.parent = self
        end

        def dictionary=(dict)
            @dictionary = dict
            @dictionary.parent = self
        end

        def pre_build
            encode!

            super
        end

        def post_build
            self.Length = @encoded_data.length

            super
        end

        def self.parse(stream, parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            dictionary = Dictionary.parse(scanner, parser)
            return dictionary if not scanner.skip(@@regexp_open)

            length = dictionary[:Length]
            if not length.is_a?(Integer)
                raw_data = scanner.scan_until(@@regexp_close)
                if raw_data.nil?
                    raise InvalidStreamObjectError,
                            "Stream shall end with a 'endstream' statement"
                end
            else
                length = length.value
                raw_data = scanner.peek(length)
                scanner.pos += length

                if not ( unmatched = scanner.scan_until(@@regexp_close) )
                    raise InvalidStreamObjectError,
                        "Stream shall end with a 'endstream' statement"
                end

                raw_data << unmatched
            end

            stm =
                if Origami::OPTIONS[:enable_type_guessing]
                    self.guess_type(dictionary).new('', dictionary)
                else
                    Stream.new('', dictionary)
                end

            raw_data.chomp!(TOKENS.last)

            if raw_data[-1,1] == "\n"
                if raw_data[-2,1] == "\r"
                    raw_data = raw_data[0, raw_data.size - 2]
                else
                    raw_data = raw_data[0, raw_data.size - 1]
                end
            end
            #raw_data.chomp! if length.is_a?(Integer) and length < raw_data.length

            stm.encoded_data = raw_data
            stm.file_offset = dictionary.file_offset

            stm
        end

        #
        # Iterates over each Filter in the Stream.
        #
        def each_filter
            filters = self.Filter

            return enum_for(__method__) do
                case filters
                when NilClass then 0
                when Array then filters.length
                else
                    1
                end
            end unless block_given?

            return if filters.nil?

            if filters.is_a?(Array)
                filters.each do |filter| yield(filter) end
            else
                yield(filters)
            end

            self
        end

        #
        # Returns an Array of Filters for this Stream.
        #
        def filters
            self.each_filter.to_a
        end

        #
        # Set predictor type for the current Stream.
        # Applies only for LZW and FlateDecode filters.
        #
        def set_predictor(predictor, colors: 1, bitspercomponent: 8, columns: 1)
            filters = self.filters

            layer = filters.index(:FlateDecode) or filters.index(:LZWDecode)
            if layer.nil?
                raise InvalidStreamObjectError, 'Predictor functions can only be used with Flate or LZW filters'
            end

            params = Filter::LZW::DecodeParms.new
            params[:Predictor] = predictor
            params[:Colors] = colors if colors != 1
            params[:BitsPerComponent] = bitspercomponent if bitspercomponent != 8
            params[:Columns] = columns if columns != 1

            set_decode_params(layer, params)

            self
        end

        def cast_to(type, _parser = nil)
            assert_cast_type(type)

            cast = type.new("", self.dictionary.copy)
            cast.encoded_data = self.encoded_data.dup
            cast.file_offset = self.file_offset

            transfer_attributes(cast)
        end

        def value #:nodoc:
            self
        end

        #
        # Returns the uncompressed stream content.
        #
        def data
            self.decode! unless decoded?

            @data
        end
        alias decoded_data data

        #
        # Sets the uncompressed stream content.
        # _str_:: The new uncompressed data.
        #
        def data=(str)
            @encoded_data = nil
            @data = str
        end
        alias decoded_data= data=

        #
        # Returns the raw compressed stream content.
        #
        def encoded_data
            self.encode! unless encoded?

            @encoded_data
        end

        #
        # Sets the raw compressed stream content.
        # _str_:: the new raw data.
        #
        def encoded_data=(str)
            @encoded_data = str
            @data = nil
        end

        #
        # Uncompress the stream data.
        #
        def decode!
            self.decrypt! if self.is_a?(Encryption::EncryptedStream)
            return if decoded?

            filters = self.filters
            dparams = decode_params

            @data = @encoded_data.dup
            @data.freeze

            filters.each_with_index do |filter, layer|
                params = dparams[layer].is_a?(Dictionary) ? dparams[layer] : {}

                # Handle Crypt filters.
                if filter == :Crypt
                    raise Filter::Error, "Crypt filter must be the first filter" unless layer.zero?

                    # Skip the Crypt filter.
                    next
                end

                begin
                    @data = decode_data(@data, filter, params)
                rescue Filter::Error => error
                    @data = error.decoded_data
                    raise
                end
            end

            self
        end

        #
        # Compress the stream data.
        #
        def encode!
            return if encoded?

            filters = self.filters
            dparams = decode_params

            @encoded_data = @data.dup
            (filters.length - 1).downto(0) do |layer|
                params = dparams[layer].is_a?(Dictionary) ? dparams[layer] : {}
                filter = filters[layer]

                # Handle Crypt filters.
                if filter == :Crypt
                    raise Filter::Error, "Crypt filter must be the first filter" unless layer.zero?

                    # Skip the Crypt filter.
                    next
                end

                @encoded_data = encode_data(@encoded_data, filter, params)
            end

            self.Length = @encoded_data.length

            self
        end

        def to_s(indent: 1, tab: "\t", eol: $/) #:nodoc:
            content = ""

            content << @dictionary.to_s(indent: indent, tab: tab)
            content << "stream" + eol
            content << self.encoded_data
            content << eol << TOKENS.last

            super(content, eol: eol)
        end

        def [](key) #:nodoc:
            @dictionary[key]
        end

        def []=(key, val) #:nodoc:
            @dictionary[key] = val
        end

        def each_key(&b) #:nodoc:
            @dictionary.each_key(&b)
        end

        def each_pair(&b) #:nodoc
            @dictionary.each_pair(&b)
        end
        alias each each_pair

        def key?(name)
            @dictionary.key?(name)
        end
        alias has_key? key?

        def keys
            @dictionary.keys
        end

        private

        def decoded? #:nodoc:
            not @data.nil?
        end

        def encoded? #:nodoc:
            not @encoded_data.nil?
        end

        def each_decode_params
            params = self.DecodeParms

            return enum_for(__method__) do
                case params
                when NilClass then 0
                when Array then params.length
                else
                    1
                end
            end unless block_given?

            return if params.nil?

            if params.is_a?(Array)
                params.each do |param| yield(param) end
            else
                yield(params)
            end

            self
        end

        def decode_params
            each_decode_params.to_a
        end

        def set_decode_params(layer, params) #:nodoc:
            dparms = self.DecodeParms
            unless dparms.is_a? ::Array
                @dictionary[:DecodeParms] = dparms = []
            end

            if layer > dparms.length - 1
                dparms.concat(::Array.new(layer - dparms.length + 1, Null.new))
            end

            dparms[layer] = params
            @dictionary[:DecodeParms] = dparms.first if dparms.length == 1

            self
        end

        def decode_data(data, filter, params) #:nodoc:
            filter_module(filter).decode(data, params)
        end

        def encode_data(data, filter, params) #:nodoc:
            mod = filter_module(filter)

            encoded = mod.encode(data, params)

            if %i[ASCIIHexDecode ASCII85Decode AHx A85].include?(filter.value)
                encoded << mod::EOD
            end

            encoded
        end

        def filter_module(name)
            unless name.is_a?(Name)
                raise InvalidObjectStreamObjectError, "Filter has invalid type #{name.type}"
            end

            unless DEFINED_FILTERS.include?(name.value)
                raise InvalidStreamObjectError, "Invalid filter : #{name}"
            end

            Filter.const_get(name.value.to_s.sub(/Decode$/, ""))
        end
    end

    #
    # Class representing an external Stream.
    #
    class ExternalStream < Stream

        def initialize(filespec, hash = {})
            hash[:F] = filespec
            super('', hash)
        end
    end

    class InvalidObjectStreamObjectError < InvalidStreamObjectError  #:nodoc:
    end

    #
    # Class representing a Stream containing other Objects.
    #
    class ObjectStream < Stream
        include Enumerable

        NUM = 0 #:nodoc:
        OBJ = 1 #:nodoc:

        field   :Type,            :Type => Name, :Default => :ObjStm, :Required => true, :Version => "1.5"
        field   :N,               :Type => Integer, :Required => true
        field   :First,           :Type => Integer, :Required => true
        field   :Extends,         :Type => ObjectStream

        #
        # Creates a new Object Stream.
        # _dictionary_:: A hash of attributes to set to the Stream.
        # _raw_data_:: The Stream data.
        #
        def initialize(raw_data = "", dictionary = {})
            super

            @objects = nil
        end

        def pre_build #:nodoc:
            load!

            prolog = ""
            data = ""
            objoff = 0
            @objects.to_a.sort.each do |num,obj|

                obj.set_indirect(false)
                obj.objstm_offset = objoff

                prolog << "#{num} #{objoff} "
                objdata = "#{obj} "

                objoff += objdata.size
                data << objdata
                obj.set_indirect(true)
                obj.no = num
            end

            self.data = prolog + data

            @dictionary[:N] = @objects.size
            @dictionary[:First] = prolog.size

            super
        end

        #
        # Adds a new Object to this Stream.
        # _object_:: The Object to append.
        #
        def <<(object)
            unless object.generation == 0
                raise InvalidObjectError, "Cannot store an object with generation > 0 in an ObjectStream"
            end

            if object.is_a?(Stream)
                raise InvalidObjectError, "Cannot store a Stream in an ObjectStream"
            end

            # We must have an associated document to generate new object numbers.
            if @document.nil?
                raise InvalidObjectError, "The ObjectStream must be added to a document before inserting objects"
            end

            # The object already belongs to a document.
            unless object.document.nil?
                object = import_object_from_document(object)
            end

            load!

            object.no, object.generation = @document.allocate_new_object_number if object.no == 0
            store_object(object)

            Reference.new(object.no, 0)
        end
        alias insert <<

        #
        # Deletes Object _no_.
        #
        def delete(no)
            load!

            @objects.delete(no)
        end

        #
        # Returns the index of Object _no_.
        #
        def index(no)
            @objects.to_a.sort.index { |num, _| num == no }
        end

        #
        # Returns a given decompressed object contained in the Stream.
        # _no_:: The Object number.
        #
        def extract(no)
            load!

            @objects[no]
        end

        #
        # Returns a given decompressed object by index.
        # _index_:: The Object index in the ObjectStream.
        #
        def extract_by_index(index)
            load!

            raise TypeError, "index must be an integer" unless index.is_a?(::Integer)
            raise IndexError, "index #{index} out of range" if index < 0 or index >= @objects.size

            @objects.to_a.sort[index][1]
        end

        #
        # Returns whether a specific object is contained in this stream.
        # _no_:: The Object number.
        #
        def include?(no)
            load!

            @objects.include?(no)
        end

        #
        # Iterates over each object in the stream.
        #
        def each(&b)
            load!

            @objects.values.each(&b)
        end
        alias each_object each

        #
        # Returns the number of objects contained in the stream.
        #
        def length
            raise InvalidObjectStreamObjectError, "Invalid number of objects" unless self.N.is_a?(Integer)

            self.N.to_i
        end

        #
        # Returns the array of inner objects.
        #
        def objects
            load!

            @objects.values
        end

        private

        #
        # Preprocess the object in case it already belongs to a document.
        # If the document is the same as the current object stream, remove the duplicate object from our document.
        # If the object comes from another document, use the export method to create a version without references.
        #
        def import_object_from_document(object)
            obj_doc = object.document

            # Remove the previous instance if the object is indirect to avoid duplicates.
            if obj_doc.equal?(@document)
                @document.delete_object(object.reference) if object.indirect?

            # Otherwise, create a exported version of the object.
            else
                object = object.export
            end

            object
        end

        def store_object(object) #:nodoc:
            object.set_indirect(true)       # all stored objects are indirect.
            object.parent = self            # set this stream as the parent.
            object.set_document(@document)  # inherit document information.

            @objects[object.no] = object
        end

        def load! #:nodoc:
            return unless @objects.nil?

            decode!

            @objects = {}
            return if @data.empty?

            data = StringScanner.new(@data)
            nums = []
            offsets = []
            first_offset = first_object_offset

            self.length.times do
                nums << Integer.parse(data).to_i
                offsets << Integer.parse(data).to_i
            end

            self.length.times do |i|
                unless (0...@data.size).cover?(first_object_offset + offsets[i]) and offsets[i] >= 0
                    raise InvalidObjectStreamObjectError, "Invalid offset '#{offsets[i]} for object #{nums[i]}"
                end

                data.pos = first_offset + offsets[i]
                type = Object.typeof(data)
                raise InvalidObjectStreamObjectError,
                        "Bad embedded object format in object stream" if type.nil?

                embeddedobj = type.parse(data)
                embeddedobj.no = nums[i] # object number
                embeddedobj.objstm_offset = offsets[i]

                store_object(embeddedobj)
            end
        end

        def first_object_offset #:nodoc:
            raise InvalidObjectStreamObjectError, "Invalid First offset" unless self.First.is_a?(Integer)
            raise InvalidObjectStreamObjectError, "Negative object offset" if self.First < 0

            return self.First.to_i
        end
    end

end
