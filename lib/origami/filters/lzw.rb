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

            class DecodeParms < Dictionary
                include StandardObject

                field   :Predictor,         :Type => Integer, :Default => 1
                field   :Colors,            :Type => Integer, :Default => 1
                field   :BitsPerComponent,  :Type => Integer, :Default => 8
                field   :Columns,           :Type => Integer, :Default => 1
                field   :EarlyChange,       :Type => Integer, :Default => 1
            end

            EOD = 257 #:nodoc:
            CLEARTABLE = 256 #:nodoc:

            #
            # Creates a new LZW Filter.
            # _parameters_:: A hash of filter options (ignored).
            #
            def initialize(parameters = {})
                super(DecodeParms.new(parameters))
            end

            #
            # Encodes given data using LZW compression method.
            # _stream_:: The data to encode.
            #
            def encode(string)
                if @params.Predictor.is_a?(Integer)
                    colors  = @params.Colors.is_a?(Integer) ?  @params.Colors.to_i : 1
                    bpc     = @params.BitsPerComponent.is_a?(Integer) ? @params.BitsPerComponent.to_i : 8
                    columns = @params.Columns.is_a?(Integer) ? @params.Columns.to_i : 1

                    string = Predictor.do_pre_prediction(string,
                                                         predictor: @params.Predictor.to_i,
                                                         colors: colors,
                                                         bpc: bpc,
                                                         columns: columns)
                end

                codesize = 9
                result = Utils::BitWriter.new
                result.write(CLEARTABLE, codesize)
                table = clear({})

                s = ''
                string.each_byte do |byte|
                    char = byte.chr

                    case table.size
                    when 512 then codesize = 10
                    when 1024 then codesize = 11
                    when 2048 then codesize = 12
                    when 4096
                        result.write(CLEARTABLE, codesize)
                        codesize = 9
                        clear table
                        redo
                    end

                    it = s + char
                    if table.has_key?(it)
                        s = it
                    else
                        result.write(table[s], codesize)
                        table[it] = table.size
                        s = char
                    end
                end

                result.write(table[s], codesize)
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
                codesize = 9
                table = clear(Hash.new)
                prevbyte = nil

                until bstring.eod? do
                    byte = bstring.read(codesize)

                    case table.size
                    when 510 then codesize = 10
                    when 1022 then codesize = 11
                    when 2046 then codesize = 12
                    when 4095
                        if byte != CLEARTABLE
                            raise InvalidLZWDataError.new(
                                    "LZW table is full and no clear flag was set (codeword #{byte.to_s(2).rjust(codesize,'0')} at bit #{bstring.pos - codesize}/#{bstring.size})",
                                    input_data: string,
                                    decoded_data: result
                            )
                        end
                    end

                    if byte == CLEARTABLE
                        codesize = 9
                        clear table
                        prevbyte = nil
                        redo
                    elsif byte == EOD
                        break
                    else
                        if prevbyte.nil?
                            raise InvalidLZWDataError.new(
                                    "No entry for codeword #{byte.to_s(2).rjust(codesize,'0')}.",
                                    input_data: string,
                                    decoded_data: result
                            ) unless table.value?(byte)

                            prevbyte = byte
                            result << table.key(byte)
                            redo
                        else
                            raise InvalidLZWDataError.new(
                                    "No entry for codeword #{prevbyte.to_s(2).rjust(codesize,'0')}.",
                                    input_data: string,
                                    decoded_data: result
                            ) unless table.value?(prevbyte)

                            if table.value?(byte)
                                entry = table.key(byte)
                            else
                                entry = table.key(prevbyte)
                                entry += entry[0,1]
                            end

                            result << entry
                            table[table.key(prevbyte) + entry[0,1]] = table.size
                            prevbyte = byte
                        end
                    end
                end

                if @params.Predictor.is_a?(Integer)
                    colors  = @params.Colors.is_a?(Integer) ?  @params.Colors.to_i : 1
                    bpc     = @params.BitsPerComponent.is_a?(Integer) ? @params.BitsPerComponent.to_i : 8
                    columns = @params.Columns.is_a?(Integer) ? @params.Columns.to_i : 1

                    result = Predictor.do_post_prediction(result,
                                                          predictor: @params.Predictor.to_i,
                                                          colors: colors,
                                                          bpc: bpc,
                                                          columns: columns)
                end

                result
            end

            private

            def clear(table) #:nodoc:
                table.clear
                256.times do |i|
                    table[i.chr] = i
                end

                table[CLEARTABLE] = CLEARTABLE
                table[EOD] = EOD

                table
            end
        end

    end
end
