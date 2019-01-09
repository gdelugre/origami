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
        # Returns the current trailer.
        # This might be either a Trailer or XRefStream.
        #
        def trailer
            #
            # First look for a standard trailer dictionary
            #
            if @revisions.last.trailer.dictionary?
                trl = @revisions.last.trailer

            #
            # Otherwise look for a xref stream.
            #
            else
                trl = @revisions.last.xrefstm
            end

            raise InvalidPDFError, "No trailer found" if trl.nil?

            trl
        end

        private

        def trailer_key?(attr) #:nodoc:
            !!trailer_key(attr)
        end

        def trailer_key(attr) #:nodoc:
            @revisions.reverse_each do |rev|
                if rev.trailer.dictionary? and rev.trailer.key?(attr)
                    return rev.trailer[attr].solve
                elsif rev.xrefstm?
                    xrefstm = rev.xrefstm
                    if xrefstm.is_a?(XRefStream) and xrefstm.key?(attr)
                        return xrefstm[attr].solve
                    end
                end
            end

            nil
        end

        def generate_id
            id = HexaString.new Random.new.bytes 16
            self.trailer.ID = [ id, id ]
        end
    end

    class InvalidTrailerError < Error #:nodoc:
    end

    # Forward declarations.
    class Catalog < Dictionary; end
    class Metadata < Dictionary; end

    #
    # Class representing a PDF file Trailer.
    #
    class Trailer
        include StandardObject

        TOKENS = %w{ trailer %%EOF } #:nodoc:
        XREF_TOKEN = "startxref" #:nodoc:

        @@regexp_open   = Regexp.new(WHITESPACES + TOKENS.first + WHITESPACES)
        @@regexp_xref   = Regexp.new(WHITESPACES + XREF_TOKEN + WHITESPACES + "(?<startxref>\\d+)")
        @@regexp_close  = Regexp.new(WHITESPACES + TOKENS.last + WHITESPACES)

        attr_accessor :document
        attr_accessor :startxref
        attr_reader :dictionary

        field   :Size,      :Type => Integer, :Required => true
        field   :Prev,      :Type => Integer
        field   :Root,      :Type => Catalog, :Required => true
        field   :Encrypt,   :Type => Encryption::Standard::Dictionary
        field   :Info,      :Type => Metadata
        field   :ID,        :Type => Array.of(String, length: 2)
        field   :XRefStm,   :Type => Integer

        #
        # Creates a new Trailer.
        # _startxref_:: The file _offset_ to the XRef::Section.
        # _dictionary_:: A hash of attributes to set in the Trailer Dictionary.
        #
        def initialize(startxref = 0, dictionary = {})
            @startxref, self.dictionary = startxref, dictionary && Dictionary.new(dictionary)
        end

        def self.parse(stream, parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)

            if scanner.skip(@@regexp_open)
                dictionary = Dictionary.parse(scanner, parser)
            else
                dictionary = nil
            end

            if not scanner.scan(@@regexp_xref)
                raise InvalidTrailerError, "Cannot get startxref value"
            end

            startxref = scanner['startxref'].to_i

            if not scanner.scan(@@regexp_close)
                parser.warn("No %%EOF token found") if parser
            end

            Trailer.new(startxref, dictionary)
        end

        #
        # Returns true if the specified key is present in the Trailer dictionary.
        #
        def key?(key)
            self.dictionary? and @dictionary.key?(key)
        end

        #
        # Access a key in the trailer dictionary if present.
        #
        def [](key)
            @dictionary[key] if dictionary?
        end

        #
        # Sets a value in the trailer dictionary.
        #
        def []=(key, value)
            self.dictionary = Dictionary.new unless dictionary?
            @dictionary[key] = value
        end

        #
        # Sets the trailer dictionary.
        #
        def dictionary=(dict)
            dict.parent = self if dict
            @dictionary = dict
        end

        #
        # Returns true if the Trailer contains a Dictionary.
        #
        def dictionary?
            not @dictionary.nil?
        end

        #
        # Outputs self into PDF code.
        #
        def to_s(indent: 1, eol: $/)
            content = ""
            if self.dictionary?
                content << TOKENS.first << eol << @dictionary.to_s(indent: indent, eol: eol) << eol
            end

            content << XREF_TOKEN << eol << @startxref.to_s << eol << TOKENS.last << eol

            content
        end
    end

end
