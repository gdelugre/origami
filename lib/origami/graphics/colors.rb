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

                if (color.respond_to? :r and color.respond_to? :g and color.respond_to? :b)
                    r = (color.respond_to?(:r) ? color.r : color[0]).to_f / 255
                    g = (color.respond_to?(:g) ? color.g : color[1]).to_f / 255
                    b = (color.respond_to?(:b) ? color.b : color[2]).to_f / 255
                    return [r, g, b]

                elsif (color.respond_to? :c and color.respond_to? :m and color.respond_to? :y and color.respond_to? :k)
                    c = (color.respond_to?(:c) ? color.c : color[0]).to_f
                    m = (color.respond_to?(:m) ? color.m : color[1]).to_f
                    y = (color.respond_to?(:y) ? color.y : color[2]).to_f
                    k = (color.respond_to?(:k) ? color.k : color[3]).to_f
                    return [c,m,y,k]

                elsif color.respond_to?:g or (0.0..1.0) === color
                    g = color.respond_to?(:g) ? color.g : color
                    return [ g ]

                else
                    raise TypeError, "Invalid color : #{color}"
                end
            end
        end
    end

    class PDF::Instruction

        insn  'CS', Name do |canvas, cs| canvas.gs.stroking_colorspace = cs end
        insn  'cs', Name do |canvas, cs| canvas.gs.nonstroking_colorspace = cs end
        insn  'SC', '*' do |canvas, *c| canvas.gs.stroking_color = c end
        insn  'sc', '*' do |canvas, *c| canvas.gs.nonstroking_color = c end

        insn  'G', Real do |canvas, c|
            unless (0..1).include? c
                raise Graphics::InvalidColorError,
                        "Not a valid color for DeviceGray: #{c}"
            end

            canvas.gs.stroking_colorspace = Graphics::Color::Space::DEVICE_GRAY
            canvas.gs.stroking_color = [ c ]
        end

        insn  'g', Real do |canvas, c|
            unless (0..1).include? c
                raise Graphics::InvalidColorError,
                        "Not a valid color for DeviceGray: #{c}"
            end

            canvas.gs.nonstroking_colorspace = Graphics::Color::Space::DEVICE_GRAY
            canvas.gs.nonstroking_color = [ c ]
        end

        insn  'RG', Real, Real, Real do |canvas, r,g,b|
            color = [ r, g, b ]
            unless color.all? {|comp| (0..1).include? comp}
                raise Graphics::InvalidColorError,
                        "Not a valid color for DeviceRGB: #{color.inspect}"
            end

            canvas.gs.stroking_colorspace = Graphics::Color::Space::DEVICE_RGB
            canvas.gs.stroking_color = color
        end

        insn  'rg', Real, Real, Real do |canvas, r,g,b|
            color = [ r, g, b ]
            unless color.all? {|comp| (0..1).include? comp}
                raise Graphics::InvalidColorError,
                        "Not a valid color for DeviceRGB: #{color.inspect}"
            end

            canvas.gs.nonstroking_colorspace = Graphics::Color::Space::DEVICE_RGB
            canvas.gs.nonstroking_color = color
        end

        insn  'K', Real, Real, Real, Real do |canvas, c,m,y,k|
            color = [ c, m, y, k ]
            unless color.all? {|comp| (0..1).include? comp}
                raise Graphics::InvalidColorError,
                        "Not a valid color for DeviceCMYK: #{color.inspect}"
            end

            canvas.gs.stroking_colorspace = Graphics::Color::Space::DEVICE_CMYK
            canvas.gs.stroking_color = color
        end

        insn  'k', Real, Real, Real, Real do |canvas, c,m,y,k|
            color = [ c, m, y, k ]
            unless color.all? {|comp| (0..1).include? comp}
                raise Graphics::InvalidColorError,
                        "Not a valid color for DeviceCMYK: #{color.inspect}"
            end

            canvas.gs.nonstroking_colorspace = Graphics::Color::Space::DEVICE_CMYK
            canvas.gs.nonstroking_color = color
        end
    end

end
