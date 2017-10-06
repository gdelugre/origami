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

require 'origami/filters/predictors'

module Origami

    module Filter

        class InvalidLZWDataError < DecodeError #:nodoc:
        end

        #
        # Class representing a filter used to encode and decode data with LZW compression algorithm.
        #
        class LZW
            include Filter
            include Predictor

            EOD = 257 #:nodoc:
            CLEARTABLE = 256 #:nodoc:

            #
            # Encodes given data using LZW compression method.
            # _stream_:: The data to encode.
            #
            def encode(string)
                input = pre_prediction(string)

                table, codesize = reset_state
                result = Utils::BitWriter.new
                result.write(CLEARTABLE, codesize)

                s = ''
                input.each_byte do |byte|
                    char = byte.chr

                    if table.size == 4096
                        result.write(CLEARTABLE, codesize)
                        table, _ = reset_state
                    end

                    codesize = table.size.bit_length

                    it = s + char
                    if table.has_key?(it)
                        s = it
                    else
                        result.write(table[s], codesize)
                        table[it] = table.size
                        s = char
                    end
                end

                result.write(table[s], codesize) unless s.empty?
                result.write(EOD, codesize)

                result.final.to_s
            end

            #
            # Decodes given data using LZW compression method.
            # _stream_:: The data to decode.
            #
            def decode(string)
                result = "".b
                bstring = Utils::BitReader.new(string)
                table, codesize = reset_state
                prevbyte = nil

                until bstring.eod? do
                    byte = bstring.read(codesize)
                    break if byte == EOD

                    if byte == CLEARTABLE
                        table, codesize = reset_state
                        prevbyte = nil
                        redo
                    end

                    begin
                        codesize = decode_codeword_size(table)
                        result << decode_byte(table, prevbyte, byte, codesize)
                    rescue InvalidLZWDataError => error
                        error.message.concat " (bit pos #{bstring.pos - codesize})"
                        error.input_data = string
                        error.decoded_data = result
                        raise(error)
                    end

                    prevbyte = byte
                end

                post_prediction(result)
            end

            private

            def decode_codeword_size(table)
                case table.size
                when 258...510 then 9
                when 510...1022 then 10
                when 1022...2046 then 11
                when 2046...4095 then 12
                else
                    raise InvalidLZWDataError, "LZW table is full and no clear flag was set"
                end
            end

            def decode_byte(table, previous_byte, byte, codesize) #:nodoc:

                # Ensure the codeword can be decoded in the current state.
                check_codeword(table, previous_byte, byte, codesize)

                if previous_byte.nil?
                    table.key(byte)
                else
                    if table.value?(byte)
                        entry = table.key(byte)
                    else
                        entry = table.key(previous_byte)
                        entry += entry[0, 1]
                    end

                    table[table.key(previous_byte) + entry[0,1]] = table.size

                    entry
                end
            end

            def check_codeword(table, previous_byte, byte, codesize) #:nodoc:
                if (previous_byte.nil? and not table.value?(byte)) or (previous_byte and not table.value?(previous_byte))
                    codeword = previous_byte || byte
                    raise InvalidLZWDataError, "No entry for codeword #{codeword.to_s(2).rjust(codesize, '0')}"
                end
            end

            def reset_state #:nodoc:
                table = {}
                256.times do |i|
                    table[i.chr] = i
                end

                table[CLEARTABLE] = CLEARTABLE
                table[EOD] = EOD

                # Codeword table, codeword size
                [table, 9]
            end
        end

    end
end
