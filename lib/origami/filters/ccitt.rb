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

require 'origami/filters/ccitt/tables'

module Origami

    module Filter

        class InvalidCCITTFaxDataError < DecodeError #:nodoc:
        end

        class CCITTFaxFilterError < Error #:nodoc:
        end

        #
        # Class representing a Filter used to encode and decode data with CCITT-facsimile compression algorithm.
        #
        class CCITTFax
            include Filter

            class DecodeParms < Dictionary
                include StandardObject

                field   :K,           :Type => Integer, :Default => 0
                field   :EndOfLine,   :Type => Boolean, :Default => false
                field   :EncodedByteAlign,  :Type => Boolean, :Default => false
                field   :Columns,     :Type => Integer, :Default => 1728
                field   :Rows,        :Type => Integer, :Default => 0
                field   :EndOfBlock,  :Type => Boolean, :Default => true
                field   :BlackIs1,    :Type => Boolean, :Default => false
                field   :DamagedRowsBeforeError,  :Type => :Integer, :Default => 0
            end

            EOL = codeword('000000000001')
            RTC = codeword('000000000001' * 6)

            #
            # Creates a new CCITT Fax Filter.
            #
            def initialize(parameters = {})
                super(DecodeParms.new(parameters))
            end

            #
            # Encodes data using CCITT-facsimile compression method.
            #
            def encode(stream)
                mode = @params.key?(:K) ? @params.K.value : 0
                colors = (@params.BlackIs1 == true) ? [0,1] : [1,0]
                use_eob = (@params.EndOfBlock.nil? or @params.EndOfBlock == true)
                use_eol = (@params.EndOfLine == true)
                white, _black = colors

                bitr = Utils::BitReader.new(stream)
                bitw = Utils::BitWriter.new

                unless mode.is_a?(::Integer) and mode <= 0
                    raise NotImplementedError.new("CCITT encoding scheme not supported", input_data: stream)
                end

                # Use a single row if no width has been set.
                @params[:Columns] ||= stream.size * 8
                columns = @params.Columns.value

                unless columns.is_a?(::Integer) and columns >= 0
                    raise CCITTFaxFilterError.new("Invalid value for parameter `Columns'", input_data: stream)
                end

                if columns > 0
                    # Group 4 requires an imaginary white line
                    if mode < 0
                        prev_line = Utils::BitWriter.new
                        write_bit_range(prev_line, white, columns)
                        prev_line = Utils::BitReader.new(prev_line.final.to_s)
                    end

                    until bitr.eod?
                        # Emit line synchronization code.
                        bitw.write(*EOL) if use_eol

                        case
                        when mode == 0
                            encode_one_dimensional_line(bitr, bitw, columns, colors)
                        when mode < 0
                            encode_two_dimensional_line(bitr, bitw, columns, colors, prev_line)
                        end
                    end
                end

                # Emit return-to-control code.
                bitw.write(*RTC) if use_eob

                bitw.final.to_s
            end

            #
            # Decodes data using CCITT-facsimile compression method.
            #
            def decode(stream)
                mode = @params.key?(:K) ? @params.K.value : 0

                unless mode.is_a?(::Integer) and mode <= 0
                    raise NotImplementedError.new("CCITT encoding scheme not supported", input_data: stream)
                end

                columns = @params.has_key?(:Columns) ? @params.Columns.value : 1728
                unless columns.is_a?(::Integer) and columns >= 0
                    raise CCITTFaxFilterError.new("Invalid value for parameter `Columns'", input_data: stream)
                end

                colors = (@params.BlackIs1 == true) ? [0,1] : [1,0]
                white, _black = colors
                params =
                {
                    is_aligned?: (@params.EncodedByteAlign == true),
                    has_eob?: (@params.EndOfBlock.nil? or @params.EndOfBlock == true),
                    has_eol?: (@params.EndOfLine == true)
                }

                unless params[:has_eob?]
                    rows = @params.key?(:Rows) ? @params.Rows.value : 0

                    unless rows.is_a?(::Integer) and rows >= 0
                        raise CCITTFaxFilterError.new("Invalid value for parameter `Rows'", input_data: stream)
                    end
                end

                bitr = Utils::BitReader.new(stream)
                bitw = Utils::BitWriter.new

                # Group 4 requires an imaginary white line
                if columns > 0 and mode < 0
                    prev_line = Utils::BitWriter.new
                    write_bit_range(prev_line, white, columns)
                    prev_line = Utils::BitReader.new(prev_line.final.to_s)
                end

                until bitr.eod? or rows == 0
                    # realign the read line on a 8-bit boundary if required
                    align_input(bitr) if params[:is_aligned?]

                    # received return-to-control code
                    if params[:has_eob?] and bitr.peek(RTC[1]) == RTC[0]
                        bitr.pos += RTC[1]
                        break
                    end

                    break if columns == 0

                    # checking for the presence of EOL
                    if bitr.peek(EOL[1]) != EOL[0]
                        raise InvalidCCITTFaxDataError.new(
                                "No end-of-line pattern found (at bit pos #{bitr.pos}/#{bitr.size}})",
                                input_data: stream,
                                decoded_data: bitw.final.to_s
                        ) if params[:has_eol?]
                    else
                        bitr.pos += EOL[1]
                    end

                    begin
                        case
                        when mode == 0
                            decode_one_dimensional_line(bitr, bitw, columns, colors)
                        when mode < 0
                            decode_two_dimensional_line(bitr, bitw, columns, colors, prev_line)
                        end
                    rescue DecodeError => error
                        error.input_data = stream
                        error.decoded_data = bitw.final.to_s

                        raise error
                    end

                    rows -= 1 unless params[:has_eob?]
                end

                bitw.final.to_s
            end

            private

            def encode_one_dimensional_line(input, output, columns, colors) #:nodoc:
                scan_len = 0
                white, _black = colors
                current_color = white
                length = 0

                return if columns == 0

                # Process each bit in line.
                loop do
                    if input.read(1) == current_color
                        scan_len += 1
                    else
                        if current_color == white
                            put_white_bits(output, scan_len)
                        else
                            put_black_bits(output, scan_len)
                        end

                        current_color ^= 1
                        scan_len = 1
                    end

                    length += 1
                    break if length == columns
                end

                if current_color == white
                    put_white_bits(output, scan_len)
                else
                    put_black_bits(output, scan_len)
                end

                # Align encoded lign on a 8-bit boundary.
                align_output(write) if @params.EncodedByteAlign == true
            end

            # Align input to a byte boundary.
            def align_input(input)
                return if input.pos % 8 == 0
                input.pos += 8 - (input.pos % 8)
            end

            # Align output to a byte boundary by adding some zeros.
            def align_output(output)
                return if output.pos % 8 == 0
                output.write(0, 8 - (output.pos % 8))
            end

            def encode_two_dimensional_line(_input, _output, _columns, _colors, _prev_line) #:nodoc:
                raise NotImplementedError "CCITT two-dimensional encoding scheme not supported."
            end

            def decode_one_dimensional_line(input, output, columns, colors) #:nodoc:
                white, _black = colors
                current_color = white

                line_length = 0
                while line_length < columns
                    if current_color == white
                        bit_length = get_white_bits(input)
                    else
                        bit_length = get_black_bits(input)
                    end

                    raise InvalidCCITTFaxDataError, "Unfinished line (at bit pos #{input.pos}/#{input.size}})" if bit_length.nil?

                    line_length += bit_length

                    raise InvalidCCITTFaxDataError, "Line is too long (at bit pos #{input.pos}/#{input.size}})" if line_length > columns

                    write_bit_range(output, current_color, bit_length)
                    current_color ^= 1
                end
            end

            def decode_two_dimensional_line(_input, _output, _columns, _colors, _prev_line) #:nodoc:
                raise NotImplementedError, "CCITT two-dimensional decoding scheme not supported."
            end

            def get_white_bits(bitr) #:nodoc:
                get_color_bits(bitr, WHITE_CONFIGURATION_DECODE_TABLE, WHITE_TERMINAL_DECODE_TABLE)
            end

            def get_black_bits(bitr) #:nodoc:
                get_color_bits(bitr, BLACK_CONFIGURATION_DECODE_TABLE, BLACK_TERMINAL_DECODE_TABLE)
            end

            def get_color_bits(bitr, config_words, term_words) #:nodoc:
                bits = 0
                check_conf = true

                while check_conf
                    check_conf = false
                    (2..13).each do |length|
                        codeword = bitr.peek(length)
                        config_value = config_words[[codeword, length]]

                        if config_value
                            bitr.pos += length
                            bits += config_value
                            check_conf = true if config_value == 2560
                            break
                        end
                    end
                end

                (2..13).each do |length|
                    codeword = bitr.peek(length)
                    term_value = term_words[[codeword, length]]

                    if term_value
                        bitr.pos += length
                        bits += term_value

                        return bits
                    end
                end

                nil
            end

            def lookup_bits(table, codeword, length)
                table.rassoc [codeword, length]
            end

            def put_white_bits(bitw, length) #:nodoc:
                put_color_bits(bitw, length, WHITE_CONFIGURATION_ENCODE_TABLE, WHITE_TERMINAL_ENCODE_TABLE)
            end

            def put_black_bits(bitw, length) #:nodoc:
                put_color_bits(bitw, length, BLACK_CONFIGURATION_ENCODE_TABLE, BLACK_TERMINAL_ENCODE_TABLE)
            end

            def put_color_bits(bitw, length, config_words, term_words) #:nodoc:
                while length > 2559
                    bitw.write(*config_words[2560])
                    length -= 2560
                end

                if length > 63
                    conf_length = (length >> 6) << 6
                    bitw.write(*config_words[conf_length])
                    length -= conf_length
                end

                bitw.write(*term_words[length])
            end

            def write_bit_range(bitw, bit_value, length) #:nodoc:
                bitw.write((bit_value << length) - bit_value, length)
            end
        end
        CCF = CCITTFax

    end
end
