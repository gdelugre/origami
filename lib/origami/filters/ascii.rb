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

                    # Encode the 4 bytes input value into a 5 character string.
                    value = input[i, 4].unpack("L>")[0]
                    outblock = encode_block(value)

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
                input = filter_input(string)

                i = 0
                result = ''.b

                while i < input.size

                    outblock = ""
                    value = 0
                    addend = 0

                    if input[i] == "z"
                        codelen = 1
                    else
                        codelen = 5

                        if input.length - i < codelen
                            raise InvalidASCII85StringError.new("Invalid length", input_data: string, decoded_data: result) if input.length - i == 1

                            addend = codelen - (input.length - i)
                            input << "u" * addend
                        end

                        # Decode the 5 characters input block into a 32 bit integer.
                        begin
                            value = decode_block input[i, codelen]
                        rescue InvalidASCII85StringError => error
                            error.input_data = string
                            error.decoded_data = result
                            raise(error)
                        end
                    end

                    outblock = [ value ].pack "L>"
                    outblock = outblock[0, 4 - addend]

                    result << outblock

                    i = i + codelen
                end

                result
            end

            private

            def filter_input(string)
                string = string[0, string.index(EOD)] if string.include?(EOD)
                string.delete(" \f\t\r\n\0")
            end

            #
            # Encodes an integer value into an ASCII85 block of 5 characters.
            #
            def encode_block(value)
                block = "".b

                5.times do |p|
                    c = value / 85 ** (4 - p)
                    block << ("!".ord + c).chr

                    value -= c * 85 ** (4 - p)
                end
                
                block
            end

            #
            # Decodes a 5 character ASCII85 block into an integer value.
            #
            def decode_block(block)
                value = 0

                5.times do |i|
                    byte = block[i].ord

                    if byte > "u".ord or byte < "!".ord
                        raise InvalidASCII85StringError, "Invalid character sequence: #{block.inspect}"
                    else
                        value += (byte - "!".ord) * 85 ** (4 - i)
                    end
                end

                if value >= (1 << 32)
                    raise InvalidASCII85StringError, "Invalid value (#{value}) for block #{block.inspect}"
                end

                value
            end

        end
        A85 = ASCII85

    end
end
