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

require 'date'

module Origami

    #
    # Module common to String objects.
    #
    module String

        module Encoding
            class EncodingError < Error #:nodoc:
            end

            module PDFDocEncoding
                CHARMAP =
                [
                  "\x00\x00", "\xff\xfd", "\xff\xfd", "\xff\xfd", "\xff\xfd", "\xff\xfd", "\xff\xfd", "\xff\xfd",
                  "\xff\xfd", "\x00\x09", "\x00\x0a", "\xff\xfd", "\x00\x0c", "\x00\x0d", "\xff\xfd", "\xff\xfd",
                  "\xff\xfd", "\xff\xfd", "\xff\xfd", "\xff\xfd", "\xff\xfd", "\xff\xfd", "\xff\xfd", "\xff\xfd",
                  "\x02\xd8", "\x02\xc7", "\x02\xc6", "\x02\xd9", "\x02\xdd", "\x02\xdb", "\x02\xda", "\x02\xdc",
                  "\x00\x20", "\x00\x21", "\x00\x22", "\x00\x23", "\x00\x24", "\x00\x25", "\x00\x26", "\x00\x27",
                  "\x00\x28", "\x00\x29", "\x00\x2a", "\x00\x2b", "\x00\x2c", "\x00\x2d", "\x00\x2e", "\x00\x2f",
                  "\x00\x30", "\x00\x31", "\x00\x32", "\x00\x33", "\x00\x34", "\x00\x35", "\x00\x36", "\x00\x37",
                  "\x00\x38", "\x00\x39", "\x00\x3a", "\x00\x3b", "\x00\x3c", "\x00\x3d", "\x00\x3e", "\x00\x3f",
                  "\x00\x40", "\x00\x41", "\x00\x42", "\x00\x43", "\x00\x44", "\x00\x45", "\x00\x46", "\x00\x47",
                  "\x00\x48", "\x00\x49", "\x00\x4a", "\x00\x4b", "\x00\x4c", "\x00\x4d", "\x00\x4e", "\x00\x4f",
                  "\x00\x50", "\x00\x51", "\x00\x52", "\x00\x53", "\x00\x54", "\x00\x55", "\x00\x56", "\x00\x57",
                  "\x00\x58", "\x00\x59", "\x00\x5a", "\x00\x5b", "\x00\x5c", "\x00\x5d", "\x00\x5e", "\x00\x5f",
                  "\x00\x60", "\x00\x61", "\x00\x62", "\x00\x63", "\x00\x64", "\x00\x65", "\x00\x66", "\x00\x67",
                  "\x00\x68", "\x00\x69", "\x00\x6a", "\x00\x6b", "\x00\x6c", "\x00\x6d", "\x00\x6e", "\x00\x6f",
                  "\x00\x70", "\x00\x71", "\x00\x72", "\x00\x73", "\x00\x74", "\x00\x75", "\x00\x76", "\x00\x77",
                  "\x00\x78", "\x00\x79", "\x00\x7a", "\x00\x7b", "\x00\x7c", "\x00\x7d", "\x00\x7e", "\xff\xfd",
                  "\x20\x22", "\x20\x20", "\x20\x21", "\x20\x26", "\x20\x14", "\x20\x13", "\x01\x92", "\x20\x44",
                  "\x20\x39", "\x20\x3a", "\x22\x12", "\x20\x30", "\x20\x1e", "\x20\x1c", "\x20\x1d", "\x20\x18",
                  "\x20\x19", "\x20\x1a", "\x21\x22", "\xfb\x01", "\xfb\x02", "\x01\x41", "\x01\x52", "\x01\x60",
                  "\x01\x78", "\x01\x7d", "\x01\x31", "\x01\x42", "\x01\x53", "\x01\x61", "\x01\x7e", "\xff\xfd",
                  "\x20\xac", "\x00\xa1", "\x00\xa2", "\x00\xa3", "\x00\xa4", "\x00\xa5", "\x00\xa6", "\x00\xa7",
                  "\x00\xa8", "\x00\xa9", "\x00\xaa", "\x00\xab", "\x00\xac", "\xff\xfd", "\x00\xae", "\x00\xaf",
                  "\x00\xb0", "\x00\xb1", "\x00\xb2", "\x00\xb3", "\x00\xb4", "\x00\xb5", "\x00\xb6", "\x00\xb7",
                  "\x00\xb8", "\x00\xb9", "\x00\xba", "\x00\xbb", "\x00\xbc", "\x00\xbd", "\x00\xbe", "\x00\xbf",
                  "\x00\xc0", "\x00\xc1", "\x00\xc2", "\x00\xc3", "\x00\xc4", "\x00\xc5", "\x00\xc6", "\x00\xc7",
                  "\x00\xc8", "\x00\xc9", "\x00\xca", "\x00\xcb", "\x00\xcc", "\x00\xcd", "\x00\xce", "\x00\xcf",
                  "\x00\xd0", "\x00\xd1", "\x00\xd2", "\x00\xd3", "\x00\xd4", "\x00\xd5", "\x00\xd6", "\x00\xd7",
                  "\x00\xd8", "\x00\xd9", "\x00\xda", "\x00\xdb", "\x00\xdc", "\x00\xdd", "\x00\xde", "\x00\xdf",
                  "\x00\xe0", "\x00\xe1", "\x00\xe2", "\x00\xe3", "\x00\xe4", "\x00\xe5", "\x00\xe6", "\x00\xe7",
                  "\x00\xe8", "\x00\xe9", "\x00\xea", "\x00\xeb", "\x00\xec", "\x00\xed", "\x00\xee", "\x00\xef",
                  "\x00\xf0", "\x00\xf1", "\x00\xf2", "\x00\xf3", "\x00\xf4", "\x00\xf5", "\x00\xf6", "\x00\xf7",
                  "\x00\xf8", "\x00\xf9", "\x00\xfa", "\x00\xfb", "\x00\xfc", "\x00\xfd", "\x00\xfe", "\x00\xff"
                ].map(&:b)

                def PDFDocEncoding.to_utf16be(pdfdocstr)
                    utf16bestr = UTF16BE::BOM.dup
                    pdfdocstr.each_byte do |byte|
                        utf16bestr << CHARMAP[byte]
                    end

                    utf16bestr.force_encoding('binary')
                end

                def PDFDocEncoding.to_pdfdoc(str)
                    str
                end
            end

            module UTF16BE
                BOM = "\xFE\xFF".b

                def UTF16BE.to_utf16be(str)
                    str
                end

                def UTF16BE.to_pdfdoc(str)
                    pdfdoc = []
                    i = 2

                    while i < str.size
                        char = PDFDocEncoding::CHARMAP.index(str[i,2])
                        raise EncodingError, "Can't convert UTF16-BE character to PDFDocEncoding" if char.nil?
                        pdfdoc << char
                        i = i + 2
                    end

                    pdfdoc.pack("C*")
                end
            end
        end

        include Origami::Object

        attr_accessor :encoding

        def initialize(str) #:nodoc:
            super(str.force_encoding('binary'))

            detect_encoding
        end

        #
        # Convert String object to an UTF8 encoded Ruby string.
        #
        def to_utf8
            detect_encoding

            utf16 = self.encoding.to_utf16be(self.value)
            utf16.slice!(0, Encoding::UTF16BE::BOM.size)

            utf16.encode("utf-8", "utf-16be")
        end

        #
        # Convert String object to an UTF16-BE encoded binary Ruby string.
        #
        def to_utf16be
            detect_encoding
            self.encoding.to_utf16be(self.value)
        end

        #
        # Convert String object to a PDFDocEncoding encoded binary Ruby string.
        #
        def to_pdfdoc
            detect_encoding
            self.encoding.to_pdfdoc(self.value)
        end

        def detect_encoding #:nodoc:
            if self.value[0,2] == Encoding::UTF16BE::BOM
                @encoding = Encoding::UTF16BE
            else
                @encoding = Encoding::PDFDocEncoding
            end
        end
    end

    class InvalidHexaStringObjectError < InvalidObjectError #:nodoc:
    end

    #
    # Class representing an hexadecimal-writen String Object.
    #
    class HexaString < ::String
        include String

        TOKENS = %w{ < > } #:nodoc:

        @@regexp_open = Regexp.new(WHITESPACES + TOKENS.first)
        @@regexp_close = Regexp.new(TOKENS.last)

        #
        # Creates a new PDF hexadecimal String.
        # _str_:: The string value.
        #
        def initialize(str = "")
            unless str.is_a?(::String)
                raise TypeError, "Expected type String, received #{str.class}."
            end

            super(str)
        end

        def self.parse(stream, _parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            offset = scanner.pos

            if scanner.skip(@@regexp_open).nil?
                raise InvalidHexaStringObjectError, "Hexadecimal string shall start with a '#{TOKENS.first}' token"
            end

            hexa = scanner.scan_until(@@regexp_close)
            if hexa.nil?
                raise InvalidHexaStringObjectError, "Hexadecimal string shall end with a '#{TOKENS.last}' token"
            end

            begin
                decoded = Filter::ASCIIHex.decode(hexa.chomp!(TOKENS.last))
            rescue Filter::InvalidASCIIHexStringError => e
                raise InvalidHexaStringObjectError, e.message
            end

            hexastr = HexaString.new(decoded)
            hexastr.file_offset = offset

            hexastr
        end

        def to_s(eol: $/) #:nodoc:
            super(TOKENS.first + Filter::ASCIIHex.encode(to_str) + TOKENS.last, eol: eol)
        end

        #
        # Converts self to a literal String. 
        #
        def to_literal
            LiteralString.new(self.value)
        end

        def value
            self.decrypt! if self.is_a?(Encryption::EncryptedString) and not @decrypted

            to_str
        end
    end

    class InvalidLiteralStringObjectError < InvalidObjectError #:nodoc:
    end

    #
    # Class representing a literal String Object.
    #
    class LiteralString < ::String
        include String

        TOKENS = %w{ ( ) } #:nodoc:

        @@regexp_open = Regexp.new(WHITESPACES + Regexp.escape(TOKENS.first))
        @@regexp_close = Regexp.new(Regexp.escape(TOKENS.last))

        #
        # Creates a new PDF String.
        # _str_:: The string value.
        #
        def initialize(str = "")
            unless str.is_a?(::String)
                raise TypeError, "Expected type String, received #{str.class}."
            end

            super(str)
        end

        def self.parse(stream, _parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            offset = scanner.pos

            unless scanner.skip(@@regexp_open)
                raise InvalidLiteralStringObjectError, "No literal string start token found"
            end

            result = ""
            depth = 0
            while depth != 0 or scanner.peek(1) != TOKENS.last do
                raise InvalidLiteralStringObjectError, "Non-terminated string" if scanner.eos?

                c = scanner.get_byte
                case c
                when "\\"
                    if scanner.match?(/\d{1,3}/)
                        oct = scanner.peek(3).oct.chr
                        scanner.pos += 3
                        result << oct
                    elsif scanner.match?(/((\r?\n)|(\r\n?))/)
                        scanner.skip(/((\r?\n)|(\r\n?))/)
                        next
                    else
                        flag = scanner.get_byte
                        case flag
                        when "n" then result << "\n"
                        when "r" then result << "\r"
                        when "t" then result << "\t"
                        when "b" then result << "\b"
                        when "f" then result << "\f"
                        else
                            result << flag
                        end
                    end

                when "(" then
                    depth = depth + 1
                    result << c
                when ")" then
                    depth = depth - 1
                    result << c
                else
                    result << c
                end
            end

            unless scanner.skip(@@regexp_close)
                raise InvalidLiteralStringObjectError, "Byte string shall be terminated with '#{TOKENS.last}'"
            end

            # Try to cast as a Date object if possible.
            if result[0, 2] == 'D:'
                begin
                    date = Date.parse(result)
                    date.file_offset = offset
                    return date
                rescue InvalidDateError
                end
            end

            bytestr = self.new(result)
            bytestr.file_offset = offset

            bytestr
        end

        def to_s(eol: $/) #:nodoc:
            super(TOKENS.first + expand + TOKENS.last, eol: eol)
        end

        #
        # Converts self to HexaString
        #
        def to_hex
            HexaString.new(self.value)
        end

        #
        # Returns a standard String representation.
        #
        def value
            self.decrypt! if self.is_a?(Encryption::EncryptedString) and not @decrypted

            to_str
        end

        private

        def expand #:nodoc:
            self.gsub(/[\n\r\t\b\f()\\]/,
                      "\n" => "\\n",
                      "\r" => "\\r",
                      "\t" => "\\t",
                      "\b" => "\\b",
                      "\f" => "\\f",
                      "\\" => "\\\\",
                      "(" => "\\(",
                      ")" => "\\)")
        end
    end

    class InvalidDateError < Error #:nodoc:
    end

    #
    # Class representing a Date string.
    #
    class Date < LiteralString #:nodoc:

        REGEXP_TOKEN =
            /D:                         # Date header
             (?<year>\d{4})             # Year
             (?<month>\d{2})?           # Month
             (?<day>\d{2})?             # Day
             (?<hour>\d{2})?            # Hour
             (?<min>\d{2})?             # Minute
             (?<sec>\d{2})?             # Second
             (?:
                 (?<ut>[\+\-Z])             # UT relationship
                 (?<ut_hour_off>\d{2})      # UT hour offset
                 ('(?<ut_min_off>\d{2}))?   # UT minute offset
             )?
            /x

        attr_reader :year, :month, :day, :hour, :min, :sec, :utc_offset

        def initialize(year:, month: 1, day: 1, hour: 0, min: 0, sec: 0, utc_offset: 0)
            @year, @month, @day, @hour, @min, @sec = year, month, day, hour, min, sec
            @utc_offset = utc_offset

            date = "D:%04d%02d%02d%02d%02d%02d" % [year, month, day, hour, min, sec ]

            if utc_offset == 0
                date << "Z00'00"
            else
                date << (if utc_offset < 0 then '-' else '+' end)
                off_hours, off_secs = utc_offset.abs.divmod(3600)
                off_mins = off_secs / 60
                date << "%02d'%02d" % [ off_hours, off_mins ]
            end

            super(date)
        end

        def to_datetime
            ::DateTime.new(@year, @month, @day, @hour, @min, @sec, (@utc_offset / 3600).to_s)
        end

        def self.parse(str) #:nodoc:
            raise InvalidDateError, "Not a valid Date string" unless str =~ REGEXP_TOKEN

            date =
            {
                year: $~['year'].to_i
            }

            date[:month] = $~['month'].to_i if $~['month']
            date[:day] = $~['day'].to_i if $~['day']
            date[:hour] = $~['hour'].to_i if $~['hour']
            date[:min] = $~['min'].to_i if $~['min']
            date[:sec] = $~['sec'].to_i if $~['sec']

            if %w[+ -].include?($~['ut'])
                utc_offset = $~['ut_hour_off'].to_i * 3600 + $~['ut_min_off'].to_i * 60
                utc_offset = -utc_offset if $~['ut'] == '-'

                date[:utc_offset] = utc_offset
            end

            Origami::Date.new(date)
        end

        #
        # Returns current Date String in UTC time.
        #
        def self.now
            now = Time.now.utc

            date =
            {
                year: now.strftime("%Y").to_i,
                month: now.strftime("%m").to_i,
                day: now.strftime("%d").to_i,
                hour: now.strftime("%H").to_i,
                min: now.strftime("%M").to_i,
                sec: now.strftime("%S").to_i,
                utc_offset: now.utc_offset
            }

            Origami::Date.new(date)
        end
    end

end
