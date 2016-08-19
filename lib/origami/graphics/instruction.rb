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

    class InvalidPDFInstructionError < Error; end

    class PDF::Instruction
        using TypeConversion

        attr_reader :operator
        attr_accessor :operands

        @insns = Hash.new(operands: [], render: lambda{})

        def initialize(operator, *operands)
            @operator = operator
            @operands = operands.map!{|arg| arg.is_a?(Origami::Object) ? arg.value : arg}

            if self.class.has_op?(operator)
                opdef = self.class.get_operands(operator)

                if not opdef.include?('*') and opdef.size != operands.size
                    raise InvalidPDFInstructionError,
                            "Numbers of operands mismatch for #{operator}: #{operands.inspect}"
                end
            end
        end

        def render(canvas)
            self.class.get_render_proc(@operator)[canvas, *@operands]

            self
        end

        def to_s
            "#{operands.map{|op| op.to_o.to_s}.join(' ')}#{' ' unless operands.empty?}#{operator}\n"
        end

        class << self
            def insn(operator, *operands, &render_proc)
                @insns[operator] = {}
                @insns[operator][:operands] = operands
                @insns[operator][:render] = render_proc || lambda{}
            end

            def has_op?(operator)
                @insns.has_key? operator
            end

            def get_render_proc(operator)
                @insns[operator][:render]
            end

            def get_operands(operator)
                @insns[operator][:operands]
            end

            def parse(stream)
                operands = []
                while type = Object.typeof(stream, true)
                    operands.push type.parse(stream)
                end

                if not stream.eos?
                    if stream.scan(/(?<operator>[[:graph:]&&[^\[\]<>()%\/]]+)/).nil?
                        raise InvalidPDFInstructionError, "Operator: #{(stream.peek(10) + '...').inspect}"
                    end

                    operator = stream['operator']
                    PDF::Instruction.new(operator, *operands)
                else
                    unless operands.empty?
                        raise InvalidPDFInstructionError, "No operator given for operands: #{operands.map(&:to_s).join(' ')}"
                    end
                end
            end
        end

    end
end
