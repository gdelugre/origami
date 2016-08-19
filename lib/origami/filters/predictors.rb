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

        class PredictorError < Error #:nodoc:
        end

        module Predictor
            NONE = 1
            TIFF = 2
            PNG_NONE = 10
            PNG_SUB = 11
            PNG_UP = 12
            PNG_AVERAGE = 13
            PNG_PAETH = 14
            PNG_OPTIMUM = 15

            def self.do_pre_prediction(data, predictor: NONE, colors: 1, bpc: 8, columns: 1)
                return data if predictor == NONE

                unless (1..4) === colors.to_i
                    raise PredictorError.new("Colors must be between 1 and 4", input_data: data)
                end

                unless [1,2,4,8,16].include?(bpc.to_i)
                    raise PredictorError.new("BitsPerComponent must be in 1, 2, 4, 8 or 16", input_data: data)
                end

                # components per line
                nvals = columns * colors

                # bytes per pixel
                bpp = (colors * bpc + 7) >> 3

                # bytes per row
                bpr = (nvals * bpc + 7) >> 3

                unless data.size % bpr == 0
                    raise PredictorError.new("Invalid data size #{data.size}, should be multiple of bpr=#{bpr}", input_data: data)
                end

                if predictor == TIFF
                    do_tiff_pre_prediction(data, colors, bpc, columns)
                elsif predictor >= 10 # PNG
                    do_png_pre_prediction(data, predictor, bpp, bpr)
                else
                    raise PredictorError.new("Unknown predictor : #{predictor}", input_data: data)
                end
            end

            def self.do_post_prediction(data, predictor: NONE, colors: 1, bpc: 8, columns: 1)
                return data if predictor == NONE

                unless (1..4) === colors
                    raise PredictorError.new("Colors must be between 1 and 4", input_data: data)
                end

                unless [1,2,4,8,16].include?(bpc)
                    raise PredictorError.new("BitsPerComponent must be in 1, 2, 4, 8 or 16", input_data: data)
                end

                # components per line
                nvals = columns * colors

                # bytes per pixel
                bpp = (colors * bpc + 7) >> 3

                # bytes per row
                bpr = ((nvals * bpc + 7) >> 3) + 1

                if predictor == TIFF
                    do_tiff_post_prediction(data, colors, bpc, columns)
                elsif predictor >= 10 # PNG
                    do_png_post_prediction(data, bpp, bpr)
                else
                    raise PredictorError.new("Unknown predictor : #{predictor}", input_data: data)
                end
            end

            def self.do_png_post_prediction(data, bpp, bpr)
                result = ""
                uprow = "\0" * bpr
                thisrow = "\0" * bpr
                nrows = (data.size + bpr - 1) / bpr

                nrows.times do |irow|
                    line = data[irow * bpr, bpr]
                    predictor = 10 + line[0].ord
                    line[0] = "\0"

                    for i in (1..line.size-1)
                        up = uprow[i].ord

                        if bpp > i
                            left = upleft = 0
                        else
                            left = line[i-bpp].ord
                            upleft = uprow[i-bpp].ord
                        end

                        case predictor
                        when PNG_NONE
                            thisrow = line
                        when PNG_SUB
                            thisrow[i] = ((line[i].ord + left) & 0xFF).chr
                        when PNG_UP
                            thisrow[i] = ((line[i].ord + up) & 0xFF).chr
                        when PNG_AVERAGE
                            thisrow[i] = ((line[i].ord + ((left + up) / 2)) & 0xFF).chr
                        when PNG_PAETH
                            p = left + up - upleft
                            pa, pb, pc = (p - left).abs, (p - up).abs, (p - upleft).abs

                            thisrow[i] = ((line[i].ord +
                                case [ pa, pb, pc ].min
                                when pa then left
                                when pb then up
                                when pc then upleft
                                end
                            ) & 0xFF).chr
                        else
                            unless Origami::OPTIONS[:ignore_png_errors]
                                raise PredictorError.new("Unknown PNG predictor : #{predictor}", input_data: data, decoded_data: result)
                            end

                            # behave as PNG_NONE
                            thisrow = line
                        end
                    end

                    result << thisrow[1..-1]
                    uprow = thisrow
                end

                result
            end

            def self.do_png_pre_prediction(data, predictor, bpp, bpr)
                result = ""
                nrows = data.size / bpr

                line = "\0" + data[-bpr, bpr]

                (nrows-1).downto(0) do |irow|
                    uprow =
                    if irow == 0
                        "\0" * (bpr+1)
                    else
                        "\0" + data[(irow-1)*bpr,bpr]
                    end

                    bpr.downto(1) do |i|
                        up = uprow[i].ord
                        left = line[i-bpp].ord
                        upleft = uprow[i-bpp].ord

                        case predictor
                        when PNG_SUB
                            line[i] = ((line[i].ord - left) & 0xFF).chr
                        when PNG_UP
                            line[i] = ((line[i].ord - up) & 0xFF).chr
                        when PNG_AVERAGE
                            line[i] = ((line[i].ord - ((left + up) / 2)) & 0xFF).chr
                        when PNG_PAETH
                            p = left + up - upleft
                            pa, pb, pc = (p - left).abs, (p - up).abs, (p - upleft).abs

                            line[i] = ((line[i].ord -
                                case [ pa, pb, pc ].min
                                when pa then left
                                when pb then up
                                when pc then upleft
                                end
                            ) & 0xFF).chr
                        when PNG_NONE
                        else
                            raise PredictorError.new("Unsupported PNG predictor : #{predictor}", input_data: data)
                        end
                    end

                    line[0] = (predictor - 10).chr
                    result = line + result

                    line = uprow
                end

                result
            end

            def self.do_tiff_post_prediction(data, colors, bpc, columns) #:nodoc:
                bpr = (colors * bpc * columns + 7) >> 3
                nrows = data.size / bpr
                bitmask = (1 << bpc) - 1
                result = Utils::BitWriter.new

                nrows.times do |irow|
                    line = Utils::BitReader.new(data[irow * bpr, bpr])

                    pixel = ::Array.new(colors, 0)
                    columns.times do
                        diffpixel = ::Array.new(colors) { line.read(bpc) }
                        pixel = pixel.zip(diffpixel).map!{|c, diff| (c + diff) & bitmask}

                        pixel.each do |c|
                            result.write(c, bpc)
                        end
                    end

                    result.final
                end

                result.final.to_s
            end

            def self.do_tiff_pre_prediction(data, colors, bpc, columns) #:nodoc:
                bpr = (colors * bpc * columns + 7) >> 3
                nrows = data.size / bpr
                bitmask = (1 << bpc) - 1
                result = Utils::BitWriter.new

                nrows.times do |irow|
                    line = Utils::BitReader.new(data[irow * bpr, bpr])

                    diffpixel = ::Array.new(colors, 0)
                    columns.times do
                        pixel = ::Array.new(colors) { line.read(bpc) }
                        diffpixel = diffpixel.zip(pixel).map!{|diff, c| (c - diff) & bitmask}

                        diffpixel.each do |c|
                            result.write(c, bpc)
                        end
                    end

                    result.final
                end

                result.final.to_s
            end
        end

    end
end
