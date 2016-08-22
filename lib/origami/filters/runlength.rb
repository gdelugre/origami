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

        class InvalidRunLengthDataError < DecodeError #:nodoc:
        end

        #
        # Class representing a Filter used to encode and decode data using RLE compression algorithm.
        #
        class RunLength
            include Filter

            EOD = 128 #:nodoc:

            #
            # Encodes data using RLE compression method.
            # _stream_:: The data to encode.
            #
            def encode(stream)
                result = "".b
                i = 0

                while i < stream.size

                    # How many identical bytes coming?
                    length = compute_run_length(stream, i)

                    # If more than 1, then compress them.
                    if length > 1
                        result << (257 - length).chr << stream[i]
                        i += length

                    # Otherwise how many different bytes to copy?
                    else
                        next_pos = find_next_run(stream, i)
                        length = next_pos - i

                        result << (length - 1).chr << stream[i, length]

                        i += length
                    end
                end

                result << EOD.chr
            end

            #
            # Decodes data using RLE decompression method.
            # _stream_:: The data to decode.
            #
            def decode(stream)
                result = "".b

                i = 0
                until i >= stream.length or stream[i].ord == EOD do

                    # At least two bytes are required.
                    if i > stream.length - 2
                        raise InvalidRunLengthDataError.new("Truncated run-length data", input_data: stream, decoded_data: result)
                    end

                    length = stream[i].ord
                    if length < EOD
                        result << stream[i + 1, length + 1]
                        i = i + length + 2
                    else
                        result << stream[i + 1] * (257 - length)
                        i = i + 2
                    end
                end

                # Check if offset is beyond the end of data.
                if i > stream.length
                    raise InvalidRunLengthDataError.new("Truncated run-length data", input_data: stream, decoded_data: result)
                end

                result
            end

            private

            #
            # Find the position of the next byte at which a new run starts.
            #
            def find_next_run(input, pos)
                start = pos
                pos += 1 while pos + 1 < input.size and (pos - start + 1) < EOD and input[pos] != input[pos + 1]

                pos + 1
            end

            #
            # Computes the length of the run at the given position.
            #
            def compute_run_length(input, pos)
                run_length = 1
                while pos + 1 < input.size and run_length < EOD and input[pos] == input[pos + 1]
                    run_length += 1
                    pos += 1
                end

                run_length
            end
        end
        RL = RunLength

    end
end
