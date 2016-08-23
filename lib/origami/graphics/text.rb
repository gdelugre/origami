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

    module Text

        OPERATORS =
        [
            'Tc', 'Tw', 'Tz', 'TL', 'Tf', 'Tr', 'Ts',   # Text state
            'BT', 'ET',                                 # Text objects
            'Td', 'TD', 'Tm', 'T*',                     # Positioning
            'Tj', "'", '"', 'TJ'                        # Showing
        ]

        module Rendering
            FILL                      = 0
            STROKE                    = 1
            FILL_AND_STROKE           = 2
            INVISIBLE                 = 3
            FILL_AND_CLIP             = 4
            STROKE_AND_CLIP           = 5
            FILL_AND_STROKE_AND_CLIP  = 6
            CLIP                      = 7
        end

        class TextStateError < Error #:nodoc:
        end

        class State
            attr_accessor :char_spacing, :word_spacing, :scaling, :leading
            attr_accessor :font, :font_size
            attr_accessor :rendering_mode
            attr_accessor :text_rise, :text_knockout

            attr_accessor :text_matrix, :text_line_matrix, :text_rendering_matrix

            def initialize
                self.reset
            end

            def reset
                @char_spacing = 0
                @word_spacing = 0
                @scaling = 100
                @leading = 0
                @font = nil
                @font_size = nil
                @rendering_mode = Rendering::FILL
                @text_rise = 0
                @text_knockout = true

                #
                # Text objects
                #

                @text_object = false
                @text_matrix =
                @text_line_matrix =
                @text_rendering_matrix = nil
            end

            def is_in_text_object?
                @text_object
            end

            def begin_text_object
                if is_in_text_object?
                    raise TextStateError, "Cannot start a text object within an existing text object."
                end

                @text_object = true
                @text_matrix =
                @text_line_matrix =
                @text_rendering_matrix = Matrix.identity(3)
            end

            def end_text_object
                unless is_in_text_object?
                  raise TextStateError, "Cannot end text object : no previous text object has begun."
                end

                @text_object = false
                @text_matrix =
                @text_line_matrix =
                @text_rendering_matrix = nil
            end
        end #class State
    end #module Text

    class PDF::Instruction
        #
        # Text instructions definitions
        #
        insn 'Tc', Real do |canvas, cS| canvas.gs.text_state.char_spacing = cS end
        insn 'Tw', Real do |canvas, wS| canvas.gs.text_state.word_spacing = wS end
        insn 'Tz', Real do |canvas, s| canvas.gs.text_state.scaling = s end
        insn 'TL', Real do |canvas, l| canvas.gs.text_state.leading = l end

        insn 'Tf', Name, Real do |canvas, font, size|
            canvas.gs.text_state.font = font
            canvas.gs.text_state.font_size = size
        end

        insn 'Tr', Integer do |canvas, r| canvas.gs.text_state.rendering_mode = r end
        insn 'Ts', Real do |canvas, s| canvas.gs.text_state.text_rise = s end
        insn 'BT' do |canvas| canvas.gs.text_state.begin_text_object end
        insn 'ET' do |canvas| canvas.gs.text_state.end_text_object end

        insn 'Td', Real, Real do |canvas, tx, ty|
            unless canvas.gs.text_state.is_in_text_object?
                raise TextStateError, "Must be in a text object to use operator : Td"
            end

            canvas.gs.text_state.text_matrix =
            canvas.gs.text_state.text_line_matrix =
            Matrix.rows([[1,0,0],[0,1,0],[tx, ty, 1]]) * canvas.gs.text_state.text_line_matrix
        end

        insn 'TD', Real, Real do |canvas, tx, ty|
            unless canvas.gs.text_state.is_in_text_object?
                raise TextStateError, "Must be in a text object to use operator : TD"
            end

            canvas.gs.text_state.leading = -ty

            canvas.gs.text_state.text_matrix =
            canvas.gs.text_state.text_line_matrix =
            Matrix.rows([[1,0,0],[0,1,0],[tx,ty,1]]) * canvas.gs.text_state.text_line_matrix
        end

        insn 'Tm', Real, Real, Real, Real, Real, Real do |canvas, a, b, c, d, e, f|
            unless canvas.gs.text_state.is_in_text_object?
                raise TextStateError, "Must be in a text object to use operator : Tm"
            end

            canvas.gs.text_state.text_matrix =
            canvas.gs.text_state.text_line_matrix =
            Matrix.rows([[a,b,0],[c,d,0],[e,f,1]])
        end

        insn 'T*' do |canvas|
            unless canvas.gs.text_state.is_in_text_object?
                raise TextStateError, "Must be in a text object to use operator : T*"
            end

            tx, ty = 0, -canvas.gs.text_state.leading

            canvas.gs.text_state.text_matrix =
            canvas.gs.text_state.text_line_matrix =
            Matrix.rows([[1,0,0],[0,1,0],[tx, ty, 1]]) * canvas.gs.text_state.text_line_matrix
        end

        insn 'Tj', String do |canvas, s|
            unless canvas.gs.text_state.is_in_text_object?
                raise TextStateError, "Must be in a text object to use operator : Tj"
            end

            canvas.write_text(s)
        end

        insn "'", String do |canvas, s|
            unless canvas.gs.text_state.is_in_text_object?
                raise TextStateError, "Must be in a text object to use operator : '"
            end

            tx, ty = 0, -canvas.gs.text_state.leading

            canvas.gs.text_state.text_matrix =
            canvas.gs.text_state.text_line_matrix =
            Matrix.rows([[1,0,0],[0,1,0],[tx, ty, 1]]) * canvas.gs.text_state.text_line_matrix

            canvas.write_text(s)
        end

        insn '"', Real, Real, String do |canvas, w, c, s|
            unless canvas.gs.text_state.is_in_text_object?
                raise TextStateError, "Must be in a text object to use operator : \""
            end

            canvas.gs.text_state.word_spacing = w
            canvas.gs.text_state.char_spacing = c

            tx, ty = 0, -gs.text_state.leading

            canvas.gs.text_state.text_matrix =
            canvas.gs.text_state.text_line_matrix =
            Matrix.rows([[1,0,0],[0,1,0],[tx, ty, 1]]) * canvas.gs.text_state.text_line_matrix

            canvas.write_text(s)
        end

        insn 'TJ', Array do |canvas, arr|
            arr.each do |g|
                case g
                when Fixnum,Float then
                    # XXX: handle this in text space ?
                when ::String then
                    canvas.write_text(g)
                else
                    raise InvalidPDFInstructionError,
                            "Invalid component type `#{g.class}` in TJ operand"
                end
            end
        end
    end

end
