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
            if @revisions.last.trailer.has_dictionary?
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
                if rev.trailer.has_dictionary? and not rev.trailer[attr].nil?
                    return rev.trailer[attr].solve
                elsif rev.has_xrefstm?
                    xrefstm = rev.xrefstm
                    if xrefstm.is_a?(XRefStream) and xrefstm.has_field?(attr)
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

            if stream.skip(@@regexp_open)
                dictionary = Dictionary.parse(stream, parser)
            else
                dictionary = nil
            end

            if not stream.scan(@@regexp_xref)
                #raise InvalidTrailerError, "Cannot get startxref value"
            end

            startxref = stream['startxref'].to_i

            if not stream.scan(@@regexp_close)
                #raise InvalidTrailerError, "No %%EOF token found"
            end

            Trailer.new(startxref, dictionary)
        end

        def [](key)
            @dictionary[key] if has_dictionary?
        end

        def []=(key,val)
            @dictionary[key] = val
        end

        def dictionary=(dict)
            dict.parent = self if dict
            @dictionary = dict
        end

        def has_dictionary?
            not @dictionary.nil?
        end

        #
        # Outputs self into PDF code.
        #
        def to_s
            content = ""
            if self.has_dictionary?
                content << TOKENS.first << EOL << @dictionary.to_s << EOL
            end

            content << XREF_TOKEN << EOL << @startxref.to_s << EOL << TOKENS.last << EOL

            content
        end
    end

end
