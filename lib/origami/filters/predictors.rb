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

            class DecodeParms < Dictionary
                include StandardObject

                field   :Predictor,         :Type => Integer, :Default => 1
                field   :Colors,            :Type => Integer, :Default => 1
                field   :BitsPerComponent,  :Type => Integer, :Default => 8
                field   :Columns,           :Type => Integer, :Default => 1
            end

            def self.included(receiver)
                raise TypeError, "Predictors only applies to Filters" unless receiver.include?(Filter)
            end

            #
            # Create a new predictive Filter.
            # _parameters_:: A hash of filter options.
            #
            def initialize(parameters = {})
                super(DecodeParms.new(parameters))
            end

            private

            def pre_prediction(data)
                return data unless @params.Predictor.is_a?(Integer)

                apply_pre_prediction(data, prediction_parameters)
            end

            def post_prediction(data)
                return data unless @params.Predictor.is_a?(Integer)

                apply_post_prediction(data, prediction_parameters)
            end

            def prediction_parameters
                {
                    predictor:  @params.Predictor.to_i,
                    colors:     @params.Colors.is_a?(Integer) ? @params.Colors.to_i : 1,
                    bpc:        @params.BitsPerComponent.is_a?(Integer) ? @params.BitsPerComponent.to_i : 8,
                    columns:    @params.Columns.is_a?(Integer) ? @params.Columns.to_i : 1,
                }
            end

            def apply_pre_prediction(data, predictor: NONE, colors: 1, bpc: 8, columns: 1)
                return data if data.empty? or predictor == NONE

                bpp, bpr = compute_bpp_bpr(data, columns, colors, bpc)

                unless data.size % bpr == 0
                    raise PredictorError.new("Invalid data size #{data.size}, should be multiple of bpr=#{bpr}",
                                             input_data: data)
                end

                if predictor == TIFF
                    tiff_pre_prediction(data, colors, bpc, columns)
                elsif predictor >= 10 # PNG
                    png_pre_prediction(data, predictor, bpp, bpr)
                else
                    raise PredictorError.new("Unknown predictor : #{predictor}", input_data: data)
                end
            end

            def apply_post_prediction(data, predictor: NONE, colors: 1, bpc: 8, columns: 1)
                return data if data.empty? or predictor == NONE

                bpp, bpr = compute_bpp_bpr(data, columns, colors, bpc)

                if predictor == TIFF
                    tiff_post_prediction(data, colors, bpc, columns)
                elsif predictor >= 10 # PNG
                    # Each line has an extra predictor byte.
                    png_post_prediction(data, bpp, bpr + 1)
                else
                    raise PredictorError.new("Unknown predictor : #{predictor}", input_data: data)
                end
            end

            #
            # Computes the number of bytes per pixel and number of bytes per row.
            #
            def compute_bpp_bpr(data, columns, colors, bpc)
                unless colors.between?(1, 4)
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
                bpr = (nvals * bpc + 7) >> 3

                [ bpp, bpr ]
            end

            #
            # Decodes the PNG input data.
            # Each line should be prepended by a byte identifying a PNG predictor.
            #
            def png_post_prediction(data, bpp, bpr)
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
                            left = line[i - bpp].ord
                            upleft = uprow[i - bpp].ord
                        end

                        begin
                            thisrow[i] = png_apply_prediction(predictor, line[i].ord, up, left, upleft, &:+)
                        rescue PredictorError => error
                            thisrow[i] = line[i] if Origami::OPTIONS[:ignore_png_errors]

                            error.input_data = data
                            error.decoded_data = result
                            raise(error)
                        end
                    end

                    result << thisrow[1..-1]
                    uprow = thisrow
                end

                result
            end

            #
            # Encodes the input data given a PNG predictor.
            #
            def png_pre_prediction(data, predictor, bpp, bpr)
                result = ""
                nrows = data.size / bpr

                line = "\0" + data[-bpr, bpr]

                (nrows - 1).downto(0) do |irow|
                    uprow =
                    if irow == 0
                        "\0" * (bpr + 1)
                    else
                        "\0" + data[(irow - 1) * bpr, bpr]
                    end

                    bpr.downto(1) do |i|
                        up = uprow[i].ord
                        left = line[i - bpp].ord
                        upleft = uprow[i - bpp].ord

                        line[i] = png_apply_prediction(predictor, line[i].ord, up, left, upleft, &:-)
                    end

                    line[0] = (predictor - 10).chr
                    result = line + result

                    line = uprow
                end

                result
            end

            #
            # Computes the next component value given a predictor and adjacent components.
            # A block must be passed to apply the operation.
            #
            def png_apply_prediction(predictor, value, up, left, upleft)

                result =
                    case predictor
                    when PNG_NONE
                        value
                    when PNG_SUB
                        yield(value, left)
                    when PNG_UP
                        yield(value, up)
                    when PNG_AVERAGE
                        yield(value, (left + up) / 2)
                    when PNG_PAETH
                        yield(value, png_paeth_choose(up, left, upleft))
                    else
                        raise PredictorError, "Unsupported PNG predictor : #{predictor}"
                    end

                (result & 0xFF).chr
            end

            #
            # Choose the preferred value in a PNG paeth predictor given the left, up and up left samples.
            #
            def png_paeth_choose(left, up, upleft)
                p = left + up - upleft
                pa, pb, pc = (p - left).abs, (p - up).abs, (p - upleft).abs

                case [pa, pb, pc].min
                when pa then left
                when pb then up
                when pc then upleft
                end
            end

            def tiff_post_prediction(data, colors, bpc, columns) #:nodoc:
                tiff_apply_prediction(data, colors, bpc, columns, &:+)
            end

            def tiff_pre_prediction(data, colors, bpc, columns) #:nodoc:
                tiff_apply_prediction(data, colors, bpc, columns, &:-)
            end

            def tiff_apply_prediction(data, colors, bpc, columns) #:nodoc:
                bpr = (colors * bpc * columns + 7) >> 3
                nrows = data.size / bpr
                bitmask = (1 << bpc) - 1
                result = Utils::BitWriter.new

                nrows.times do |irow|
                    line = Utils::BitReader.new(data[irow * bpr, bpr])

                    diffpixel = ::Array.new(colors, 0)
                    columns.times do
                        pixel = ::Array.new(colors) { line.read(bpc) }
                        diffpixel = diffpixel.zip(pixel).map!{|diff, c| yield(c, diff) & bitmask}

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
