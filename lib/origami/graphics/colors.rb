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

    module Graphics

        class InvalidColorError < Error #:nodoc:
        end

        module Color

            module Intent
                ABSOLUTE = :AbsoluteColorimetric
                RELATIVE = :RelativeColorimetric
                SATURATION = :Saturation
                PERCEPTUAL = :Perceptual
            end

            module BlendMode
                NORMAL      = :Normal
                COMPATIBLE  = :Compatible
                MULTIPLY    = :Multiply
                SCREEN      = :Screen
                OVERLAY     = :Overlay
                DARKEN      = :Darken
                LIGHTEN     = :Lighten
                COLORDODGE  = :ColorDodge
                COLORBURN   = :ColorBurn
                HARDLIGHT   = :HardLight
                SOFTLIGHt   = :SoftLight
                DIFFERENCE  = :Difference
                EXCLUSION   = :Exclusion
            end

            module Space
                DEVICE_GRAY   = :DeviceGray
                DEVICE_RGB    = :DeviceRGB
                DEVICE_CMYK   = :DeviceCMYK
            end

            def self.cmyk_to_rgb(c, m, y, k)
                r = 1 - (( c * ( 1 - k ) + k ))
                g = 1 - (( m * ( 1 - k ) + k ))
                b = 1 - (( y * ( 1 - k ) + k ))

                [ r, g, b ]
            end

            def self.gray_to_rgb(g)
                [ g, g, g ]
            end

            #
            # Class representing an embedded ICC Profile stream.
            #
            class ICCProfile < Stream
                field :N,           :Type => Integer, :Required => true, :Version => '1.3'
                field :Alternate,   :Type => [ Name, Array ]
                field :Range,       :Type => Array
                field :Metadata,    :Type => Stream, :Version => '1.4'
            end

            class GrayScale
                attr_accessor :g

                def initialize(g)
                    @g = g
                end
            end

            class RGB
                attr_accessor :r,:g,:b

                def initialize(r,g,b)
                    @r,@g,@b = r,g,b
                end
            end

            class CMYK
                attr_accessor :c,:m,:y,:k

                def initialize(c,m,y,k)
                    @c,@m,@y,@k = c,m,y,k
                end
            end

            def Color.to_a(color)
                return color if color.is_a?(::Array)

                if %i(r g b).all? {|c| color.respond_to?(c)}
                    r = color.r.to_f / 255
                    g = color.g.to_f / 255
                    b = color.b.to_f / 255
                    return [r, g, b]

                elsif %i(c m y k).all? {|c| color.respond_to?(c)}
                    c = color.c
                    m = color.m
                    y = color.y
                    k = color.k
                    return [c,m,y,k]

                elsif color.respond_to?(:g)
                    g = color.g
                    return [g]

                else
                    raise TypeError, "Invalid color : #{color}"
                end
            end
        end

        class State
            def set_stroking_color(color, space = @stroking_color_space)
                check_color(space, color) 

                @stroking_colorspace = space
                @stroking_color = color
            end

            def set_nonstroking_color(color, space = @nonstroking_colorspace)
                check_color(space, color)

                @nonstroking_colorspace = space
                @nonstroking_color = color
            end

            def set_stroking_colorspace(space)
                check_color_space(space, @stroking_color)

                @stroking_color_space = space
            end

            def set_nonstroking_colorspace(space)
                check_color_space(space, @nonstroking_color)

                @nonstroking_color_space = space
            end

            private

            def check_color_space(space)
                case space
                when Color::Space::DEVICE_GRAY, Color::Space::DEVICE_RGB, Color::Space::DEVICE_CMYK
                else
                   raise InvalidColorError, "Unknown color space #{space}"
                end 
            end

            def check_color(space, color)
                valid_color =
                    case space
                    when Color::Space::DEVICE_GRAY
                        check_gray_color(color)
                    when Color::Space::DEVICE_RGB
                        check_rgb_color(color)
                    when Color::Space::DEVICE_CMYK
                        check_cmyk_color(color)
                    else
                        raise InvalidColorError, "Unknown color space #{space}"
                    end

                raise InvalidColorError, "Invalid color #{color.inspect} for #{space}" unless valid_color
            end

            def check_gray_color(color)
                color.is_a?(::Array) and color.length == 1 and (0..1).include?(color[0])
            end

            def check_rgb_color(color)
                color.is_a?(::Array) and color.length == 3 and color.all? {|c| (0..1).include?(c) }
            end

            def check_cmyk_color(color)
                color.is_a?(::Array) and color.length == 4 and color.all? {|c| (0..1).include?(c) }
            end
        end
    end

    class PDF::Instruction

        insn 'CS', Name do |canvas, cs| canvas.gs.set_stroking_colorspace(cs) end
        insn 'cs', Name do |canvas, cs| canvas.gs.set_nonstroking_colorspace(cs) end
        insn 'SC', '*' do |canvas, *c| canvas.gs.set_stroking_color(c) end
        insn 'sc', '*' do |canvas, *c| canvas.gs.set_nonstroking_color(c) end

        insn 'G', Real do |canvas, c|
            canvas.gs.set_stroking_color([c], Graphics::Color::Space::DEVICE_GRAY)
        end

        insn 'g', Real do |canvas, c|
            canvas.gs.set_nonstroking_color([c], Graphics::Color::Space::DEVICE_GRAY)
        end

        insn 'RG', Real, Real, Real do |canvas, r, g, b|
            canvas.gs.set_stroking_color([r, g, b], Graphics::Color::Space::DEVICE_RGB)
        end

        insn 'rg', Real, Real, Real do |canvas, r, g, b|
            canvas.gs.set_nonstroking_color([r, g, b], Graphics::Color::Space::DEVICE_RGB)
        end

        insn 'K', Real, Real, Real, Real do |canvas, c, m, y, k|
            canvas.gs.set_stroking_color([c, m, y, k], Graphics::Color::Space::DEVICE_CMYK)
        end

        insn 'k', Real, Real, Real, Real do |canvas, c, m, y, k|
            canvas.gs.set_nonstroking_color([c, m, y, k], Graphics::Color::Space::DEVICE_CMYK)
        end
    end

end
