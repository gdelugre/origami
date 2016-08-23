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

        module LineCapStyle
            BUTT_CAP              = 0
            ROUND_CAP             = 1
            PROJECTING_SQUARE_CAP = 2
        end

        module LineJoinStyle
            MITER_JOIN = 0
            ROUND_JOIN = 1
            BEVEL_JOIN = 2
        end

        class DashPattern
            attr_accessor :array, :phase

            def initialize(array, phase = 0)
                @array = array
                @phase = phase
            end

            def eql?(dash) #:nodoc
                dash.array == @array and dash.phase == @phase
            end

            def hash #:nodoc:
                [ @array, @phase ].hash
            end
        end

        class InvalidPathError < Error #:nodoc:
        end

        class Path
            module Segment
                attr_accessor :from, :to

                def initialize(from, to)
                    @from, @to = from, to
                end
            end

            class Line
                include Segment
            end

            attr_accessor :current_point
            attr_reader :segments

            def initialize
                @segments = []
                @current_point = nil
                @closed = false
            end

            def is_closed?
                @closed
            end

            def close!
                from = @current_point
                to = @segments.first.from

                @segments << Line.new(from, to)
                @segments.freeze
                @closed = true
            end

            def add_segment(seg)
                raise GraphicsStateError, "Cannot modify closed subpath" if is_closed?

                @segments << seg
                @current_point = seg.to
            end
        end
    end

    class PDF::Instruction
        insn 'm', Real, Real do |canvas, x,y|
            canvas.gs.current_path << (subpath = Graphics::Path.new)
            subpath.current_point = [x,y]
        end

        insn 'l', Real, Real do |canvas, x,y|
            if canvas.gs.current_path.empty?
                raise InvalidPathError, "No current point is defined"
            end

            subpath = canvas.gs.current_path.last

            from = subpath.current_point
            to = [x,y]
            subpath.add_segment(Graphics::Path::Line.new(from, to))
        end

        insn 'h' do |canvas|
            unless canvas.gs.current_path.empty?
                subpath = canvas.gs.current_path.last
                subpath.close! unless subpath.is_closed?
            end
        end

        insn 're', Real, Real, Real, Real do |canvas, x,y,width,height|
            tx = x + width
            ty = y + height
            canvas.gs.current_path << (subpath = Graphics::Path.new)
            subpath.segments << Graphics::Path::Line.new([x,y], [tx,y])
            subpath.segments << Graphics::Path::Line.new([tx,y], [tx, ty])
            subpath.segments << Graphics::Path::Line.new([tx, ty], [x, ty])
            subpath.close!
        end

        insn 'S' do |canvas|
            canvas.stroke_path
        end

        insn 's' do |canvas|
            canvas.gs.current_path.last.close!
            canvas.stroke_path
        end

        insn 'f' do |canvas|
            canvas.fill_path
        end

        insn 'F' do |canvas|
            canvas.fill_path
        end

        insn 'f*' do |canvas|
            canvas.fill_path
        end

        insn 'B' do |canvas|
            canvas.fill_path
            canvas.stroke_path
        end

        insn 'B*' do |canvas|
            canvas.fill_path
            canvas.stroke_path
        end

        insn 'b' do |canvas|
            canvas.gs.current_path.last.close!
            canvas.fill_path
            canvas.stroke_path
        end

        insn 'b*' do |canvas|
            canvas.gs.current_path.last.close!
            canvas.fill_path
            canvas.stroke_path
        end

        insn 'n'
    end

end
