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

require 'delegate'

module Origami

    class InvalidIntegerObjectError < InvalidObjectError #:nodoc:
    end

    #
    # Class representing a PDF number (Integer, or Real).
    #
    module Number
        include Origami::Object

        def ~
            self.class.new(~self.value)
        end

        def |(val)
            self.class.new(self.value | val)
        end

        def &(val)
            self.class.new(self.value & val)
        end

        def ^(val)
            self.class.new(self.value ^ val)
        end

        def <<(val)
            self.class.new(self.value << val)
        end

        def >>(val)
            self.class.new(self.value >> val)
        end

        def +(val)
            self.class.new(self.value + val)
        end

        def -(val)
            self.class.new(self.value - val)
        end

        def -@
            self.class.new(-self.value)
        end

        def *(val)
            self.class.new(self.value * val)
        end

        def /(val)
            self.class.new(self.value / val)
        end

        def abs
            self.class.new(self.value.abs)
        end

        def **(val)
            self.class.new(self.value ** val)
        end
    end

    #
    # Class representing an Integer Object.
    #
    class Integer < DelegateClass(::Integer)
        include Number

        TOKENS = [ "(\\+|-)?[\\d]+[^.]?" ] #:nodoc:
        REGEXP_TOKEN = Regexp.new(TOKENS.first)

        @@regexp = Regexp.new(WHITESPACES + "(?<int>(\\+|-)?[\\d]+)")

        #
        # Creates a new Integer from  a Ruby Fixnum / Bignum.
        # _i_:: The Integer value.
        #
        def initialize(i = 0)
            unless i.is_a?(::Integer)
                raise TypeError, "Expected type Fixnum or Bignum, received #{i.class}."
            end

            super(i)
        end

        def self.parse(stream, _parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            offset = scanner.pos

            if not scanner.scan(@@regexp)
                raise InvalidIntegerObjectError, "Invalid integer format"
            end

            value = scanner['int'].to_i
            int = Integer.new(value)
            int.file_offset = offset

            int
        end

        def to_s(eol: $/) #:nodoc:
            super(self.value.to_s, eol: eol)
        end

        alias value to_i
    end

    class InvalidRealObjectError < InvalidObjectError #:nodoc:
    end

    #
    # Class representing a Real number Object.
    # PDF real numbers are arbitrary precision numbers, depending on architectures.
    #
    class Real < DelegateClass(Float)
        include Number

        TOKENS = [ "(\\+|-)?([\\d]*\\.[\\d]+|[\\d]+\\.[\\d]*)([eE](\\+|-)?[\\d]+)?" ] #:nodoc:
        REGEXP_TOKEN = Regexp.new(TOKENS.first)

        @@regexp = Regexp.new(WHITESPACES + "(?<real>#{TOKENS.first})")

        #
        # Creates a new Real from a Ruby Float.
        # _f_:: The new Real value.
        #
        def initialize(f = 0)
            unless f.is_a?(Float)
                raise TypeError, "Expected type Float, received #{f.class}."
            end

            super(f)
        end

        def self.parse(stream, _parser = nil) #:nodoc:
            scanner = Parser.init_scanner(stream)
            offset = scanner.pos

            if not scanner.scan(@@regexp)
                raise InvalidRealObjectError, "Invalid real number format"
            end

            value = scanner['real'].to_f
            real = Real.new(value)
            real.file_offset = offset

            real
        end

        alias value to_f

        def to_s(eol: $/) #:nodoc:
            super(sprintf("%f", self).sub(/\.0*$|(\.\d*[^0])0*$/, '\1'), eol: eol)
        end
    end

end
