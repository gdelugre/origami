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

            def self.codeword(str) #:nodoc:
                [ str.to_i(2), str.length ]
            end

            EOL = codeword('000000000001')
            RTC = codeword('000000000001' * 6)

            WHITE_TERMINAL_ENCODE_TABLE =
            {
                0   => codeword('00110101'),
                1   => codeword('000111'),
                2   => codeword('0111'),
                3   => codeword('1000'),
                4   => codeword('1011'),
                5   => codeword('1100'),
                6   => codeword('1110'),
                7   => codeword('1111'),
                8   => codeword('10011'),
                9   => codeword('10100'),
                10  => codeword('00111'),
                11  => codeword('01000'),
                12  => codeword('001000'),
                13  => codeword('000011'),
                14  => codeword('110100'),
                15  => codeword('110101'),
                16  => codeword('101010'),
                17  => codeword('101011'),
                18  => codeword('0100111'),
                19  => codeword('0001100'),
                20  => codeword('0001000'),
                21  => codeword('0010111'),
                22  => codeword('0000011'),
                23  => codeword('0000100'),
                24  => codeword('0101000'),
                25  => codeword('0101011'),
                26  => codeword('0010011'),
                27  => codeword('0100100'),
                28  => codeword('0011000'),
                29  => codeword('00000010'),
                30  => codeword('00000011'),
                31  => codeword('00011010'),
                32  => codeword('00011011'),
                33  => codeword('00010010'),
                34  => codeword('00010011'),
                35  => codeword('00010100'),
                36  => codeword('00010101'),
                37  => codeword('00010110'),
                38  => codeword('00010111'),
                39  => codeword('00101000'),
                40  => codeword('00101001'),
                41  => codeword('00101010'),
                42  => codeword('00101011'),
                43  => codeword('00101100'),
                44  => codeword('00101101'),
                45  => codeword('00000100'),
                46  => codeword('00000101'),
                47  => codeword('00001010'),
                48  => codeword('00001011'),
                49  => codeword('01010010'),
                50  => codeword('01010011'),
                51  => codeword('01010100'),
                52  => codeword('01010101'),
                53  => codeword('00100100'),
                54  => codeword('00100101'),
                55  => codeword('01011000'),
                56  => codeword('01011001'),
                57  => codeword('01011010'),
                58  => codeword('01011011'),
                59  => codeword('01001010'),
                60  => codeword('01001011'),
                61  => codeword('00110010'),
                62  => codeword('00110011'),
                63  => codeword('00110100')
            }
            WHITE_TERMINAL_DECODE_TABLE = WHITE_TERMINAL_ENCODE_TABLE.invert

            BLACK_TERMINAL_ENCODE_TABLE =
            {
                0   => codeword('0000110111'),
                1   => codeword('010'),
                2   => codeword('11'),
                3   => codeword('10'),
                4   => codeword('011'),
                5   => codeword('0011'),
                6   => codeword('0010'),
                7   => codeword('00011'),
                8   => codeword('000101'),
                9   => codeword('000100'),
                10  => codeword('0000100'),
                11  => codeword('0000101'),
                12  => codeword('0000111'),
                13  => codeword('00000100'),
                14  => codeword('00000111'),
                15  => codeword('000011000'),
                16  => codeword('0000010111'),
                17  => codeword('0000011000'),
                18  => codeword('0000001000'),
                19  => codeword('00001100111'),
                20  => codeword('00001101000'),
                21  => codeword('00001101100'),
                22  => codeword('00000110111'),
                23  => codeword('00000101000'),
                24  => codeword('00000010111'),
                25  => codeword('00000011000'),
                26  => codeword('000011001010'),
                27  => codeword('000011001011'),
                28  => codeword('000011001100'),
                29  => codeword('000011001101'),
                30  => codeword('000001101000'),
                31  => codeword('000001101001'),
                32  => codeword('000001101010'),
                33  => codeword('000001101011'),
                34  => codeword('000011010010'),
                35  => codeword('000011010011'),
                36  => codeword('000011010100'),
                37  => codeword('000011010101'),
                38  => codeword('000011010110'),
                39  => codeword('000011010111'),
                40  => codeword('000001101100'),
                41  => codeword('000001101101'),
                42  => codeword('000011011010'),
                43  => codeword('000011011011'),
                44  => codeword('000001010100'),
                45  => codeword('000001010101'),
                46  => codeword('000001010110'),
                47  => codeword('000001010111'),
                48  => codeword('000001100100'),
                49  => codeword('000001100101'),
                50  => codeword('000001010010'),
                51  => codeword('000001010011'),
                52  => codeword('000000100100'),
                53  => codeword('000000110111'),
                54  => codeword('000000111000'),
                55  => codeword('000000100111'),
                56  => codeword('000000101000'),
                57  => codeword('000001011000'),
                58  => codeword('000001011001'),
                59  => codeword('000000101011'),
                60  => codeword('000000101100'),
                61  => codeword('000001011010'),
                62  => codeword('000001100110'),
                63  => codeword('000001100111')
            }
            BLACK_TERMINAL_DECODE_TABLE = BLACK_TERMINAL_ENCODE_TABLE.invert

            WHITE_CONFIGURATION_ENCODE_TABLE =
            {
                64    => codeword('11011'),
                128   => codeword('10010'),
                192   => codeword('010111'),
                256   => codeword('0110111'),
                320   => codeword('00110110'),
                384   => codeword('00110111'),
                448   => codeword('01100100'),
                512   => codeword('01100101'),
                576   => codeword('01101000'),
                640   => codeword('01100111'),
                704   => codeword('011001100'),
                768   => codeword('011001101'),
                832   => codeword('011010010'),
                896   => codeword('011010011'),
                960   => codeword('011010100'),
                1024  => codeword('011010101'),
                1088  => codeword('011010110'),
                1152  => codeword('011010111'),
                1216  => codeword('011011000'),
                1280  => codeword('011011001'),
                1344  => codeword('011011010'),
                1408  => codeword('011011011'),
                1472  => codeword('010011000'),
                1536  => codeword('010011001'),
                1600  => codeword('010011010'),
                1664  => codeword('011000'),
                1728  => codeword('010011011'),

                1792  => codeword('00000001000'),
                1856  => codeword('00000001100'),
                1920  => codeword('00000001001'),
                1984  => codeword('000000010010'),
                2048  => codeword('000000010011'),
                2112  => codeword('000000010100'),
                2176  => codeword('000000010101'),
                2240  => codeword('000000010110'),
                2340  => codeword('000000010111'),
                2368  => codeword('000000011100'),
                2432  => codeword('000000011101'),
                2496  => codeword('000000011110'),
                2560  => codeword('000000011111')
            }
            WHITE_CONFIGURATION_DECODE_TABLE = WHITE_CONFIGURATION_ENCODE_TABLE.invert

            BLACK_CONFIGURATION_ENCODE_TABLE =
            {
                64    => codeword('0000001111'),
                128   => codeword('000011001000'),
                192   => codeword('000011001001'),
                256   => codeword('000001011011'),
                320   => codeword('000000110011'),
                384   => codeword('000000110100'),
                448   => codeword('000000110101'),
                512   => codeword('0000001101100'),
                576   => codeword('0000001101101'),
                640   => codeword('0000001001010'),
                704   => codeword('0000001001011'),
                768   => codeword('0000001001100'),
                832   => codeword('0000001001101'),
                896   => codeword('0000001110010'),
                960   => codeword('0000001110011'),
                1024  => codeword('0000001110100'),
                1088  => codeword('0000001110101'),
                1152  => codeword('0000001110110'),
                1216  => codeword('0000001110111'),
                1280  => codeword('0000001010010'),
                1344  => codeword('0000001010011'),
                1408  => codeword('0000001010100'),
                1472  => codeword('0000001010101'),
                1536  => codeword('0000001011010'),
                1600  => codeword('0000001011011'),
                1664  => codeword('0000001100100'),
                1728  => codeword('0000001100101'),

                1792  => codeword('00000001000'),
                1856  => codeword('00000001100'),
                1920  => codeword('00000001001'),
                1984  => codeword('000000010010'),
                2048  => codeword('000000010011'),
                2112  => codeword('000000010100'),
                2176  => codeword('000000010101'),
                2240  => codeword('000000010110'),
                2340  => codeword('000000010111'),
                2368  => codeword('000000011100'),
                2432  => codeword('000000011101'),
                2496  => codeword('000000011110'),
                2560  => codeword('000000011111')
            }
            BLACK_CONFIGURATION_DECODE_TABLE = BLACK_CONFIGURATION_ENCODE_TABLE.invert

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
                mode = @params.has_key?(:K) ? @params.K.value : 0

                unless mode.is_a?(::Integer) and mode <= 0
                    raise NotImplementedError.new("CCITT encoding scheme not supported", input_data: stream)
                end

                columns = @params.has_key?(:Columns) ? @params.Columns.value : (stream.size << 3)
                unless columns.is_a?(::Integer) and columns > 0 #and columns % 8 == 0
                    raise CCITTFaxFilterError.new("Invalid value for parameter `Columns'", input_data: stream)
                end

                if stream.size % (columns >> 3) != 0
                    raise CCITTFaxFilterError.new("Data size is not a multiple of image width", input_data: stream)
                end

                colors = (@params.BlackIs1 == true) ? [0,1] : [1,0]
                white, _black = colors
                bitr = Utils::BitReader.new(stream)
                bitw = Utils::BitWriter.new

                # Group 4 requires an imaginary white line
                if mode < 0
                    prev_line = Utils::BitWriter.new
                    write_bit_range(prev_line, white, columns)
                    prev_line = Utils::BitReader.new(prev_line.final.to_s)
                end

                until bitr.eod?
                    case
                    when mode == 0
                        encode_one_dimensional_line(bitr, bitw, columns, colors)
                    when mode < 0
                        encode_two_dimensional_line(bitr, bitw, columns, colors, prev_line)
                    end
                end

                # Emit return-to-control code
                bitw.write(*RTC)

                bitw.final.to_s
            end

            #
            # Decodes data using CCITT-facsimile compression method.
            #
            def decode(stream)
                mode = @params.has_key?(:K) ? @params.K.value : 0

                unless mode.is_a?(::Integer) and mode <= 0
                    raise NotImplementedError.new("CCITT encoding scheme not supported", input_data: stream)
                end

                columns = @params.has_key?(:Columns) ? @params.Columns.value : 1728
                unless columns.is_a?(::Integer) and columns > 0 #and columns % 8 == 0
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
                    unless @params.has_key?(:Rows) and @params.Rows.is_a?(::Integer) and @params.Rows.value > 0
                        raise CCITTFaxFilterError.new("Invalid value for parameter `Rows'", input_data: stream)
                    end

                    rows = @params.Rows.to_i
                end

                bitr = Utils::BitReader.new(stream)
                bitw = Utils::BitWriter.new

                # Group 4 requires an imaginary white line
                if mode < 0
                    prev_line = Utils::BitWriter.new
                    write_bit_range(prev_line, white, columns)
                    prev_line = Utils::BitReader.new(prev_line.final.to_s)
                end

                until bitr.eod? or rows == 0
                    # realign the read line on a 8-bit boundary if required
                    if params[:is_aligned?] and bitr.pos % 8 != 0
                        bitr.pos += 8 - (bitr.pos % 8)
                    end

                    # received return-to-control code
                    if params[:has_eob?] and bitr.peek(RTC[1]) == RTC[0]
                        bitr.pos += RTC[1]
                        break
                    end

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
                output.write(*EOL)
                scan_len = 0
                white, _black = colors
                current_color = white

                # Process each bit in line.
                begin
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
                end while input.pos % columns != 0

                if current_color == white
                    put_white_bits(output, scan_len)
                else
                    put_black_bits(output, scan_len)
                end

                # Align encoded lign on a 8-bit boundary.
                if @params.EncodedByteAlign == true and output.pos % 8 != 0
                    output.write(0, 8 - (output.pos % 8))
                end
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
