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

require 'zlib'
require 'origami/filters/predictors'

module Origami

    module Filter

        class InvalidFlateDataError < DecodeError; end #:nodoc:

        #
        # Class representing a Filter used to encode and decode data with zlib/Flate compression algorithm.
        #
        class Flate
            include Filter
            include Predictor

            EOD = 257 #:nodoc:

            #
            # Encodes data using zlib/Deflate compression method.
            # _stream_:: The data to encode.
            #
            def encode(stream)
                Zlib::Deflate.deflate(pre_prediction(stream), Zlib::BEST_COMPRESSION)
            end

            #
            # Decodes data using zlib/Inflate decompression method.
            # _stream_:: The data to decode.
            #
            def decode(stream)
                zlib_stream = Zlib::Inflate.new
                begin
                    uncompressed = zlib_stream.inflate(stream)
                rescue Zlib::DataError => zlib_except
                    uncompressed = zlib_stream.flush_next_out

                    unless Origami::OPTIONS[:ignore_zlib_errors]
                        raise InvalidFlateDataError.new(zlib_except.message, input_data: stream, decoded_data: uncompressed)
                    end
                end

                post_prediction(uncompressed)
            end
        end
        Fl = Flate

    end
end
