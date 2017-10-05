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

        module Canvas
            attr_reader :gs

            def initialize
                @gs = Graphics::State.new
            end

            def clear
                @gs.reset
            end

            def write_text(s); end
            def stroke_path; end
            def fill_path; end
            def paint_shading(sh); end
        end

        class DummyCanvas
            include Canvas
        end

        class TextCanvas
            include Canvas

            def initialize(output = STDOUT, columns = 80, lines = 25)
                super()

                @output = output
                @columns, @lines = columns, lines
            end

            def write_text(s)
                @output.print(s)
            end
        end

    end
end
