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

    module Template

        class AxialGradient < Graphics::Pattern::Shading::Axial
            def initialize(from, to, color0, color1, coeff = 1)
                super()

                set_indirect(true)

                x, y  = from
                tx, ty = to

                c0 = Graphics::Color.to_a(color0)
                c1 = Graphics::Color.to_a(color1)

                space =
                case c0.size
                when 1 then Graphics::Color::Space::DEVICE_GRAY
                when 3 then Graphics::Color::Space::DEVICE_RGB
                when 4 then Graphics::Color::Space::DEVICE_CMYK
                end

                f = Function::Exponential.new
                f.Domain = [ 0.0, 1.0 ]
                f.N = coeff
                f.C0, f.C1 = c0, c1

                self.ColorSpace = space
                self.Coords = [ x, y, tx, ty ]
                self.Function = f
                self.Extend = [ true, true ]
            end
        end
    end
end
