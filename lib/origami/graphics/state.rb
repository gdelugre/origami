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

require 'matrix'

module Origami

    module Graphics
        class GraphicsStateError < Error #:nodoc:
        end

        class State
            #
            # Device-independent parameters.
            #
            attr_accessor :ctm
            attr_accessor :clipping_path
            attr_accessor :stroking_colorspace, :nonstroking_colorspace, :stroking_color, :nonstroking_color
            attr_accessor :text_state
            attr_accessor :line_width, :line_cap, :line_join, :miter_limit, :dash_pattern
            attr_accessor :rendering_intent
            attr_accessor :stroke_adjustment
            attr_accessor :blend_mode, :soft_mask, :alpha_constant, :alpha_source

            attr_reader :current_path

            def initialize
                @stack = []
                @current_path = []
                @text_state = Text::State.new

                self.reset
            end

            def reset
                @ctm = Matrix.identity(3)
                @clipping_path = nil
                @stroking_colorspace = @nonstroking_colorspace = Color::Space::DEVICE_GRAY
                @stroking_color = @nonstroking_color = [ 0.0 ] #black
                @text_state.reset
                @line_width = 1.0
                @line_cap = LineCapStyle::BUTT_CAP
                @line_join = LineJoinStyle::MITER_JOIN
                @miter_limit = 10.0
                @dash_pattern = DashPattern.new([], 0)
                @rendering_intent = Color::Intent::RELATIVE
                @stroke_adjustment = false
                @blend_mode = Color::BlendMode::NORMAL
                @soft_mask = :None
                @alpha_constant = 1.0
                @alpha_source = false
            end

            def save
                context =
                [
                    @ctm, @clipping_path,
                    @stroking_colorspace, @nonstroking_colorspace,
                    @stroking_color, @nonstroking_color,
                    @text_state, @line_width, @line_cap, @line_join,
                    @miter_limit, @dash_pattern, @rendering_intent,
                    @stroke_adjustment,
                    @blend_mode, @soft_mask, @alpha_constant, @alpha_source
                ]
                @stack.push(context)
            end

            def restore
                raise GraphicsStateError, "Cannot restore context : empty stack" if @stack.empty?

                @ctm, @clipping_path,
                @stroking_colorspace, @nonstroking_colorspace,
                @stroking_color, @nonstroking_color,
                @text_state, @line_width, @line_cap, @line_join,
                @miter_limit, @dash_pattern, @rendering_intent,
                @stroke_adjustment,
                @blend_mode, @soft_mask, @alpha_constant, @alpha_source = @stack.pop
            end
        end

        #
        # Generic Graphic state
        # 4.3.4 Graphics State Parameter Dictionaries p219
        #
        class ExtGState < Dictionary
            include StandardObject

            field   :Type,          :Type => Name, :Default => :ExtGState, :Required => true
            field   :LW,            :Type => Integer, :Version => "1.3"
            field   :LC,            :Type => Integer, :Version => "1.3"
            field   :LJ,            :Type => Integer, :Version => "1.3"
            field   :ML,            :Type => Number, :Version => "1.3"
            field   :D,             :Type => Array.of(Array, Integer, length: 2), :Version => "1.3"
            field   :RI,            :Type => Name, :Version => "1.3"
            field   :OP,            :Type => Boolean
            field   :op,            :Type => Boolean, :Version => "1.3"
            field   :OPM,           :Type => Number, :Version => "1.3"
            field   :Font,          :Type => Array, :Version => "1.3"
            field   :BG,            :Type => Object
            field   :BG2,           :Type => Object, :Version => "1.3"
            field   :UCR,           :Type => Object
            field   :UCR2,          :Type => Object, :Version => "1.3"
            field   :TR,            :Type => Object
            field   :TR2,           :Type => Object, :Version => "1.3"
            field   :HT,            :Type => [ Dictionary, Name, Stream ]
            field   :FL,            :Type => Number, :Version => "1.3"
            field   :SM,            :Type => Number, :Version => "1.3"
            field   :SA,            :Type => Boolean
            field   :BM,            :Type => [ Name, Array ], :Version => "1.4"
            field   :SMask,         :Type => [ Dictionary, Name ], :Version => "1.4"
            field   :CA,            :Type => Number
            field   :ca,            :Type => Number, :Version => "1.4"
            field   :AIS,           :Type => Boolean, :Version => "1.4"
            field   :TK,            :Type => Boolean, :Version => "1.4"
        end
    end #module Graphics

    class PDF::Instruction
        insn 'q' do |canvas| canvas.gs.save; canvas.gs.reset end
        insn 'Q' do |canvas| canvas.gs.restore end
        insn 'w', Real do |canvas, lw| canvas.gs.line_width = lw end
        insn 'J', Real do |canvas, lc| canvas.gs.line_cap = lc end
        insn 'j', Real do |canvas, lj| canvas.gs.line_join = lj end
        insn 'M', Real do |canvas, ml| canvas.gs.miter_limit = ml end

        insn 'd', Array, Integer do |canvas, array, phase|
            canvas.gs.dash_pattern = Graphics::DashPattern.new array, phase
        end

        insn 'ri', Name do |canvas, ri| canvas.gs.rendering_intent = ri end
    end
end
