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

    module Filter

        class InvalidASCIIHexStringError < DecodeError #:nodoc:
        end

        #
        # Class representing a filter used to encode and decode data written into hexadecimal.
        #
        class ASCIIHex
            include Filter

            EOD = ">"  #:nodoc:

            #
            # Encodes given data into upcase hexadecimal representation.
            # _stream_:: The data to encode.
            #
            def encode(stream)
                stream.unpack("H*").join.upcase
            end

            #
            # Decodes given data writen into upcase hexadecimal representation.
            # _string_:: The data to decode.
            #
            def decode(string)
                input = string.include?(EOD) ? string[0...string.index(EOD)] : string
                digits = input.delete(" \f\t\r\n\0")

                # Ensure every digit is in the hexadecimal charset.
                unless digits =~ /^\h*$/
                    digits = digits.match(/^\h*/).to_s

                    raise InvalidASCIIHexStringError.new("Invalid characters", input_data: string, decoded_data: [ digits ].pack('H*'))
                end

                [ digits ].pack "H*"
            end

        end
        AHx = ASCIIHex

        class InvalidASCII85StringError < DecodeError #:nodoc:
        end

        #
        # Class representing a filter used to encode and decode data written in base85 encoding.
        #
        class ASCII85
            include Filter

            EOD = "~>" #:nodoc:

            #
            # Encodes given data into base85.
            # _stream_:: The data to encode.
            #
            def encode(stream)
                i = 0
                code = "".b
                input = stream.dup

                while i < input.size do

                    if input.length - i < 4
                        addend = 4 - (input.length - i)
                        input << "\0" * addend
                    else
                        addend = 0
                    end

                    inblock = input[i, 4].unpack("L>")[0]
                    outblock = ""

                    5.times do |p|
                        c = inblock / 85 ** (4 - p)
                        outblock << ("!".ord + c).chr

                        inblock -= c * 85 ** (4 - p)
                    end

                    outblock = "z" if outblock == "!!!!!" and addend == 0

                    if addend != 0
                        outblock = outblock[0, 4 - addend + 1]
                    end

                    code << outblock

                    i = i + 4
                end

                code
            end

            #
            # Decodes the given data encoded in base85.
            # _string_:: The data to decode.
            #
            def decode(string)
                input = (string.include?(EOD) ? string[0..string.index(EOD) - 1] : string).delete(" \f\t\r\n\0")

                i = 0
                result = ''.b

                while i < input.size do

                    outblock = ""
                    inblock = 0
                    addend = 0

                    if input[i] == "z"
                        codelen = 1
                    else
                        codelen = 5

                        if input.length - i < 5
                            raise InvalidASCII85StringError.new("Invalid length", input_data: string, decoded_data: result) if input.length - i == 1

                            addend = 5 - (input.length - i)
                            input << "u" * addend
                        end

                        # Checking if this string is in base85
                        5.times do |j|
                            byte = input[i + j].ord

                            if byte > "u".ord or byte < "!".ord
                                raise InvalidASCII85StringError.new(
                                        "Invalid character sequence: #{input[i, 5].inspect}",
                                        input_data: string,
                                        decoded_data: result
                                )
                            else
                                inblock += (byte - "!".ord) * 85 ** (4 - j)
                            end
                        end

                        raise InvalidASCII85StringError.new(
                                "Invalid value (#{inblock}) for block #{input[i,5].inspect}",
                                input_data: string,
                                decoded_data: result
                        ) if inblock >= (1 << 32)
                    end

                    outblock = [ inblock ].pack "L>"
                    outblock = outblock[0, 4 - addend] if addend != 0

                    result << outblock

                    i = i + codelen
                end

                result
            end

        end
        A85 = ASCII85

    end
end
