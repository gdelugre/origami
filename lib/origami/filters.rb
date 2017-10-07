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

    #
    # Filters are algorithms used to encode data into a PDF Stream.
    #
    module Filter

        autoload :ASCIIHex,     "origami/filters/ascii"
        autoload :AHx,          "origami/filters/ascii"
        autoload :ASCII85,      "origami/filters/ascii"
        autoload :A85,          "origami/filters/ascii"
        autoload :CCITTFax,     "origami/filters/ccitt"
        autoload :CCF,          "origami/filters/ccitt"
        autoload :Crypt,        "origami/filters/crypt"
        autoload :DCT,          "origami/filters/dct"
        autoload :Flate,        "origami/filters/flate"
        autoload :Fl,           "origami/filters/flate"
        autoload :JBIG2,        "origami/filters/jbig2"
        autoload :JPX,          "origami/filters/jpx"
        autoload :LZW,          "origami/filters/lzw"
        autoload :RunLength,    "origami/filters/runlength"
        autoload :RL,           "origami/filters/runlength"
        autoload :Predictor,    "origami/filters/predictors"


        #
        # Base class for filter Exceptions.
        #
        class Error < Origami::Error
            attr_accessor :input_data, :decoded_data

            def initialize(message, input_data: nil, decoded_data: nil)
                super(message)

                @input_data, @decoded_data = input_data, decoded_data
            end
        end

        #
        # Exception class for unsupported filters or unsupported filter parameters.
        #
        class NotImplementedError < Error; end

        #
        # Exception class for errors occuring during decode operations.
        #
        class DecodeError < Error; end

        module Utils

            class BitWriterError < Error #:nodoc:
            end

            #
            # Class used to forge a String from a stream of bits.
            # Internally used by some filters.
            #
            class BitWriter
                def initialize
                    @data = ''.b
                    @last_byte = nil
                    @ptr_bit = 0
                end

                #
                # Writes _data_ represented as Fixnum to a _length_ number of bits.
                #
                def write(data, length)
                    return BitWriterError, "Invalid data length" unless length > 0 and length >= data.bit_length

                    # optimization for aligned byte writing
                    if length == 8 and @last_byte.nil? and @ptr_bit == 0
                        @data << data.chr
                        return self
                    end

                    write_bits(data, length)

                    self
                end

                #
                # Returns the data size in bits.
                #
                def size
                    (@data.size << 3) + @ptr_bit
                end

                #
                # Finalizes the stream.
                #
                def final
                    @data << @last_byte.chr if @last_byte
                    @last_byte = nil
                    @p = 0

                    self
                end

                #
                # Outputs the stream as a String.
                #
                def to_s
                    @data.dup
                end

                private

                #
                # Write the bits into the internal data.
                #
                def write_bits(data, length)

                    while length > 0
                        if length >= 8 - @ptr_bit
                            length -= 8 - @ptr_bit
                            @last_byte ||= 0
                            @last_byte |= (data >> length) & ((1 << (8 - @ptr_bit)) - 1)

                            data &= (1 << length) - 1
                            @data << @last_byte.chr
                            @last_byte = nil
                            @ptr_bit = 0
                        else
                            @last_byte ||= 0
                            @last_byte |= (data & ((1 << length) - 1)) << (8 - @ptr_bit - length)
                            @ptr_bit += length

                            if @ptr_bit == 8
                                @data << @last_byte.chr
                                @last_byte = nil
                                @ptr_bit = 0
                            end

                            length = 0
                        end
                    end
                end
            end

            class BitReaderError < Error #:nodoc:
            end

            #
            # Class used to read a String as a stream of bits.
            # Internally used by some filters.
            #
            class BitReader
                BRUIJIN_TABLE = ::Array.new(32)
                BRUIJIN_TABLE.size.times do |i|
                    BRUIJIN_TABLE[((0x77cb531 * (1 << i)) >> 27) & 31] = i
                end

                def initialize(data)
                    @data = data
                    reset
                end

                #
                # Resets the read pointer.
                #
                def reset
                    @ptr_byte, @ptr_bit = 0, 0
                    self
                end

                #
                # Returns true if end of data has been reached.
                #
                def eod?
                    @ptr_byte >= @data.size
                end

                #
                # Returns the read pointer position in bits.
                #
                def pos
                    (@ptr_byte << 3) + @ptr_bit
                end

                #
                # Returns the data size in bits.
                #
                def size
                    @data.size << 3
                end

                #
                # Sets the read pointer position in bits.
                #
                def pos=(bits)
                    raise BitReaderError, "Pointer position out of data" if bits > self.size

                    pbyte = bits >> 3
                    pbit = bits - (pbyte << 3)
                    @ptr_byte, @ptr_bit = pbyte, pbit
                end

                #
                # Reads _length_ bits as a Fixnum and advances read pointer.
                #
                def read(length)
                    n = self.peek(length)
                    self.pos += length

                    n
                end

                #
                # Reads _length_ bits as a Fixnum. Does not advance read pointer.
                #
                def peek(length)
                    return BitReaderError, "Invalid read length" unless length > 0
                    return BitReaderError, "Insufficient data" if self.pos + length > self.size

                    n = 0
                    ptr_byte, ptr_bit = @ptr_byte, @ptr_bit

                    while length > 0
                        byte = @data[ptr_byte].ord

                        if length > 8 - ptr_bit
                            length -= 8 - ptr_bit
                            n |= ( byte & ((1 << (8 - ptr_bit)) - 1) ) << length

                            ptr_byte += 1
                            ptr_bit = 0
                        else
                            n |= (byte >> (8 - ptr_bit - length)) & ((1 << length) - 1)
                            length = 0
                        end
                    end

                    n
                end

                #
                # Used for bit scanning.
                # Counts leading zeros. Does not advance read pointer.
                #
                def clz
                    count = 0
                    if @ptr_bit != 0
                        bits = peek(8 - @ptr_bit)
                        count = clz32(bits << (32 - (8 - @ptr_bit)))

                        return count if count < (8 - @ptr_bit)
                    end

                    delta = 0
                    while @data.size > @ptr_byte + delta * 4
                        word = @data[@ptr_byte + delta * 4, 4] # next 32 bits
                        z = clz32((word << (4 - word.size)).unpack("N")[0])

                        count += z
                        delta += 1

                        return count if z < 32 - ((4 - word.size) << 3)
                    end

                    count
                end

                #
                # Used for bit scanning.
                # Count leading ones. Does not advance read pointer.
                #
                def clo
                    count = 0
                    if @ptr_bit != 0
                        bits = peek(8 - @ptr_bit)
                        count = clz32(~(bits << (32 - (8 - @ptr_bit))) & 0xff)

                        return count if count < (8 - @ptr_bit)
                    end

                    delta = 0
                    while @data.size > @ptr_byte + delta * 4
                        word = @data[@ptr_byte + delta * 4, 4] # next 32 bits
                        z = clz32(~((word << (4 - word.size)).unpack("N")[0]) & 0xffff_ffff)

                        count += z
                        delta += 1

                        return count if z < 32 - ((4 - word.size) << 3)
                    end

                    count
                end

                private

                def bitswap8(i) #:nodoc
                    ((i * 0x0202020202) & 0x010884422010) % 1023
                end

                def bitswap32(i) #:nodoc:
                    (bitswap8((i >> 0) & 0xff) << 24) |
                    (bitswap8((i >> 8) & 0xff) << 16) |
                    (bitswap8((i >> 16) & 0xff) << 8) |
                    (bitswap8((i >> 24) & 0xff) << 0)
                end

                def ctz32(i) #:nodoc:
                    if i == 0 then 32
                    else
                        BRUIJIN_TABLE[(((i & -i) * 0x77cb531) >> 27) & 31]
                    end
                end

                def clz32(i) #:nodoc:
                    ctz32 bitswap32 i
                end
            end
        end

        module ClassMethods
            #
            # Decodes the given data.
            # _stream_:: The data to decode.
            #
            def decode(stream, params = {})
                self.new(params).decode(stream)
            end

            #
            # Encodes the given data.
            # _stream_:: The data to encode.
            #
            def encode(stream, params = {})
                self.new(params).encode(stream)
            end
        end

        def initialize(parameters = {})
            @params = parameters
        end

        def self.included(receiver)
            receiver.extend(ClassMethods)
        end
    end

end
