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

    module Function

        module Type
            SAMPLED     = 0
            EXPONENTIAL = 2
            STITCHING   = 3
            POSTSCRIPT  = 4
        end

        def self.included(receiver)
            receiver.field  :FunctionType,  :Type => Integer, :Required => true
            receiver.field  :Domain,        :Type => Array.of(Number), :Required => true
            receiver.field  :Range,         :Type => Array.of(Number)
        end

        class Sampled < Stream
            include Function

            field   :FunctionType,  :Type => Integer, :Default => Type::SAMPLED, :Version => "1.3", :Required => true
            field   :Range,         :Type => Array.of(Number), :Required => true
            field   :Size,          :Type => Array.of(Integer), :Required => true
            field   :BitsPerSample, :Type => Integer, :Required => true
            field   :Order,         :Type => Integer, :Default => 1
            field   :Encode,        :Type => Array.of(Number)
            field   :Decode,        :Type => Array.of(Number)
        end

        class Exponential < Dictionary
            include StandardObject
            include Function

            field   :FunctionType,  :Type => Integer, :Default => Type::EXPONENTIAL, :Version => "1.3", :Required => true
            field   :C0,            :Type => Array.of(Number), :Default => [ 0.0 ]
            field   :C1,            :Type => Array.of(Number), :Default => [ 1.0 ]
            field   :N,             :Type => Number, :Required => true
        end

        class Stitching < Dictionary
            include StandardObject
            include Function

            field   :FunctionType,  :Type => Integer, :Default => Type::STITCHING, :Version => "1.3", :Required => true
            field   :Functions,     :Type => Array, :Required => true
            field   :Bounds,        :Type => Array.of(Number), :Required => true
            field   :Encode,        :Type => Array.of(Number), :Required => true
        end

        class PostScript < Stream
            include Function

            field   :FunctionType,  :Type => Integer, :Default => Type::POSTSCRIPT, :Version => "1.3", :Required => true
            field   :Range,         :Type => Array.of(Number), :Required => true
        end
    end

end
