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

    class PDF
        #
        # Tries to strip any xrefs information off the document.
        #
        def remove_xrefs
            @revisions.reverse_each do |rev|
                if rev.xrefstm?
                    delete_object(rev.xrefstm.reference)
                end

                if rev.trailer.XRefStm.is_a?(Integer)
                    xrefstm = get_object_by_offset(rev.trailer.XRefStm)

                    delete_object(xrefstm.reference) if xrefstm.is_a?(XRefStream)
                end

                rev.xrefstm = rev.xreftable = nil
            end
        end
    end

    class InvalidXRefError < Error #:nodoc:
    end

    #
    # Class representing a Cross-reference information.
    #
    class XRef

        FREE = "f"
        USED = "n"
        FIRSTFREE = 65535

        @@regexp = /(?<offset>\d{10}) (?<gen>\d{5}) (?<state>n|f)(\r\n| \r| \n)/

        attr_accessor :offset, :generation, :state

        #
        # Creates a new XRef.
        # _offset_:: The file _offset_ of the referenced Object.
        # _generation_:: The generation number of the referenced Object.
        # _state_:: The state of the referenced Object (FREE or USED).
        #
        def initialize(offset, generation, state)
            @offset, @generation, @state = offset, generation, state
        end

        def self.parse(stream) #:nodoc:
            scanner = Parser.init_scanner(stream)

            if scanner.scan(@@regexp).nil?
                raise InvalidXRefError, "Invalid XRef format"
            end

            offset = scanner['offset'].to_i
            generation = scanner['gen'].to_i
            state = scanner['state']

            XRef.new(offset, generation, state)
        end

        #
        # Returns true if the associated object is used.
        #
        def used?
            @state == USED
        end

        #
        # Returns true if the associated object is freed.
        #
        def free?
            @state == FREE
        end

        #
        # Marks an XRef as freed.
        #
        def free!
            @state = FREE
        end

        #
        # Outputs self into PDF code.
        #
        def to_s(eol: $/)
            off = @offset.to_s.rjust(10, '0')
            gen = @generation.to_s.rjust(5, '0')

            "#{off} #{gen} #{@state}" + eol.rjust(2, ' ')
        end

        def to_xrefstm_data(type_w, field1_w, field2_w)
            type_w <<= 3
            field1_w <<= 3
            field2_w <<= 3

            type = ((@state == FREE) ? "\000" : "\001").unpack("B#{type_w}")[0]

            offset = @offset.to_s(2).rjust(field1_w, '0')
            generation = @generation.to_s(2).rjust(field2_w, '0')

            [ type , offset, generation ].pack("B#{type_w}B#{field1_w}B#{field2_w}")
        end

        class InvalidXRefSubsectionError < Error #:nodoc:
        end

        #
        # Class representing a cross-reference subsection.
        # A subsection contains a continute set of XRef.
        #
        class Subsection
            include Enumerable

            @@regexp = Regexp.new("(?<start>\\d+) (?<size>\\d+)" + WHITESPACES + "(\\r?\\n|\\r\\n?)")

            attr_reader :range

            #
            # Creates a new XRef subsection.
            # _start_:: The number of the first object referenced in the subsection.
            # _entries_:: An array of XRef.
            #
            def initialize(start, entries = [])
                @entries = entries.dup
                @range = Range.new(start, start + entries.size - 1)
            end

            def self.parse(stream) #:nodoc:
                scanner = Parser.init_scanner(stream)

                if scanner.scan(@@regexp).nil?
                    raise InvalidXRefSubsectionError, "Bad subsection format"
                end

                start = scanner['start'].to_i
                size = scanner['size'].to_i

                xrefs = []
                size.times do
                    xrefs << XRef.parse(scanner)
                end

                XRef::Subsection.new(start, xrefs)
            end

            #
            # Returns whether this subsection contains information about a particular object.
            # _no_:: The Object number.
            #
            def has_object?(no)
                @range.include?(no)
            end

            #
            # Returns XRef associated with a given object.
            # _no_:: The Object number.
            #
            def [](no)
                @entries[no - @range.begin]
            end

            #
            # Processes each XRef in the subsection.
            #
            def each(&b)
                @entries.each(&b)
            end

            #
            # Processes each XRef in the subsection, passing the XRef and the object number to the block.
            #
            def each_with_number
                return enum_for(__method__) { self.size } unless block_given?

                counter = @range.to_enum
                @entries.each do |entry|
                    yield(entry, counter.next)
                end
            end

            #
            # The number of entries in the subsection.
            #
            def size
                @entries.size
            end

            #
            # Outputs self into PDF code.
            #
            def to_s(eol: $/)
                section = "#{@range.begin} #{@range.end - @range.begin + 1}" + eol
                @entries.each do |xref|
                    section << xref.to_s(eol: eol)
                end

                section
            end
        end

        class InvalidXRefSectionError < Error #:nodoc:
        end

        #
        # Class representing a Cross-reference table.
        # A section contains a set of XRef::Subsection.
        #
        class Section
            include Enumerable

            TOKEN = "xref"

            @@regexp_open = Regexp.new(WHITESPACES + TOKEN + WHITESPACES + "(\\r?\\n|\\r\\n?)")
            @@regexp_sub = Regexp.new("(\\d+) (\\d+)" + WHITESPACES + "(\\r?\\n|\\r\\n?)")

            #
            # Creates a new XRef section.
            # _subsections_:: An array of XRefSubsection.
            #
            def initialize(subsections = [])
                @subsections = subsections
            end

            def self.parse(stream) #:nodoc:
                scanner = Parser.init_scanner(stream)

                if scanner.skip(@@regexp_open).nil?
                    raise InvalidXRefSectionError, "No xref token found"
                end

                subsections = []
                while scanner.match?(@@regexp_sub) do
                    subsections << XRef::Subsection.parse(scanner)
                end

                XRef::Section.new(subsections)
            end

            #
            # Appends a new subsection.
            # _subsection_:: A XRefSubsection.
            #
            def <<(subsection)
                @subsections << subsection
            end

            #
            # Returns a XRef associated with a given object.
            # _no_:: The Object number.
            #
            def [](no)
                @subsections.each do |s|
                    return s[no] if s.has_object?(no)
                end

                nil
            end
            alias find []

            #
            # Processes each XRef in each Subsection.
            #
            def each(&b)
                return enum_for(__method__) { self.size } unless block_given?

                @subsections.each do |subsection|
                    subsection.each(&b)
                end
            end

            #
            # Processes each XRef in each Subsection, passing the XRef and the object number.
            #
            def each_with_number(&b)
                return enum_for(__method__) { self.size } unless block_given?

                @subsections.each do |subsection|
                    subsection.each_with_number(&b)
                end
            end

            #
            # Processes each Subsection in this table.
            #
            def each_subsection(&b)
                @subsections.each(&b)
            end
            
            #
            # Returns an Array of Subsection.
            #
            def subsections
                @subsections
            end

            #
            # Clear all the entries.
            #
            def clear
                @subsections.clear
            end

            #
            # The number of XRef entries in the Section.
            #
            def size
                @subsections.reduce(0) { |total, subsection| total + subsection.size }
            end

            #
            # Outputs self into PDF code.
            #
            def to_s(eol: $/)
                "xref" << eol << @subsections.map{|sub| sub.to_s(eol: eol)}.join
            end
        end
    end

    #
    # An xref poiting to an Object embedded in an ObjectStream.
    #
    class XRefToCompressedObject
        attr_accessor :objstmno, :index

        def initialize(objstmno, index)
            @objstmno = objstmno
            @index = index
        end

        def to_xrefstm_data(type_w, field1_w, field2_w)
            type_w <<= 3
            field1_w <<= 3
            field2_w <<= 3

            type = "\002".unpack("B#{type_w}")[0]
            objstmno = @objstmno.to_s(2).rjust(field1_w, '0')
            index = @index.to_s(2).rjust(field2_w, '0')

            [ type , objstmno, index ].pack("B#{type_w}B#{field1_w}B#{field2_w}")
        end

        def used?; true end
        def free?; false end
    end

    class InvalidXRefStreamObjectError < InvalidStreamObjectError ; end

    #
    # Class representing a XRef Stream.
    #
    class XRefStream < Stream
        include Enumerable
        include StandardObject

        XREF_FREE = 0
        XREF_USED = 1
        XREF_COMPRESSED = 2

        #
        # Xref fields
        #
        field   :Type,          :Type => Name, :Default => :XRef, :Required => true, :Version => "1.5"
        field   :Size,          :Type => Integer, :Required => true
        field   :Index,         :Type => Array.of(Integer, Integer)
        field   :Prev,          :Type => Integer
        field   :W,             :Type => Array.of(Integer, length: 3), :Required => true

        #
        # Trailer fields
        #
        field   :Root,          :Type => Catalog, :Required => true
        field   :Encrypt,       :Type => Encryption::Standard::Dictionary
        field   :Info,          :Type => Metadata
        field   :ID,            :Type => Array.of(String, length: 2)

        def initialize(data = "", dictionary = {})
            super(data, dictionary)

            @xrefs = nil
        end

        def entries
            load! if @xrefs.nil?

            @xrefs
        end

        #
        # Returns XRef entries present in this stream.
        #
        def pre_build #:nodoc:
            load! if @xrefs.nil?

            self.W = [ 1, 2, 2 ] unless self.key?(:W)
            self.Size = @xrefs.length + 1

            save!

            super
        end

        #
        # Adds an XRef to this Stream.
        #
        def <<(xref)
            load! if @xrefs.nil?

            @xrefs << xref
        end

        #
        # Iterates over each XRef present in the stream.
        #
        def each(&b)
            load! if @xrefs.nil?

            @xrefs.each(&b)
        end

        #
        # Iterates over each XRef present in the stream, passing the XRef and its object number.
        #
        def each_with_number
            return enum_for(__method__) unless block_given?

            load! if @xrefs.nil?

            ranges = object_ranges
            xrefs = @xrefs.to_enum

            ranges.each do |range|
                range.each do |no|
                    begin
                        yield(xrefs.next, no)
                    rescue StopIteration
                        raise InvalidXRefStreamObjectError, "Range is bigger than number of entries"
                    end
                end
            end
        end

        #
        # Returns an XRef matching this object number.
        #
        def find(no)
            load! if @xrefs.nil?

            ranges = object_ranges

            index = 0
            ranges.each do |range|
                return @xrefs[index + no - range.begin] if range.cover?(no)

                index += range.size
            end

            nil
        end

        def clear
            self.data = ''
            @xrefs = []
            self.Index = []
        end

        private

        def object_ranges
            load! if @xrefs.nil?

            if self.key?(:Index)
                ranges = self.Index
                unless ranges.is_a?(Array) and ranges.length.even? and ranges.all?{|i| i.is_a?(Integer)}
                    raise InvalidXRefStreamObjectError, "Index must be an even Array of integers"
                end

                ranges.each_slice(2).map { |start, length| Range.new(start.to_i, start.to_i + length.to_i - 1) }
            else
                [ 0...@xrefs.size ]
            end
        end

        def load! #:nodoc:
            if @xrefs.nil? and self.key?(:W)
                decode!

                type_w, field1_w, field2_w = field_widths

                entrymask = "B#{type_w << 3}B#{field1_w << 3}B#{field2_w << 3}"
                size = @data.size / (type_w + field1_w + field2_w)

                xentries = @data.unpack(entrymask * size).map!{|field| field.to_i(2) }

                @xrefs = []
                xentries.each_slice(3) do |type, field1, field2|
                    case type
                    when XREF_FREE
                        @xrefs << XRef.new(field1, field2, XRef::FREE)
                    when XREF_USED
                        @xrefs << XRef.new(field1, field2, XRef::USED)
                    when XREF_COMPRESSED
                        @xrefs << XRefToCompressedObject.new(field1, field2)
                    end
                end
            else
                @xrefs = []
            end
        end

        def save! #:nodoc:
            self.data = ""

            type_w, field1_w, field2_w = self.W
            @xrefs.each do |xref| @data << xref.to_xrefstm_data(type_w, field1_w, field2_w) end

            encode!
        end

        #
        # Check and return the internal field widths.
        #
        def field_widths
            widths = self.W

            unless widths.is_a?(Array) and widths.length == 3 and widths.all? {|w| w.is_a?(Integer) and w >= 0 }
                raise InvalidXRefStreamObjectError, "Invalid W field: #{widths}"
            end

            widths
        end
    end

end
