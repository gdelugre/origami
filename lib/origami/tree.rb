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

    class InvalidNameTreeError < Error #:nodoc:
    end

    #
    # Class representing a node in a Name tree.
    #
    class NameTreeNode < Dictionary
        include StandardObject

        field   :Kids,              :Type => Array.of(self)
        field   :Names,             :Type => Array.of(String, Object)
        field   :Limits,            :Type => Array.of(String, length: 2)

        def self.of(klass)
            return Class.new(self) do
                field   :Kids,      :Type => Array.of(self)
                field   :Names,     :Type => Array.of(String, klass)
            end
        end
    end

    #
    # Class representing a node in a Number tree.
    #
    class NumberTreeNode < Dictionary
        include StandardObject

        field   :Kids,              :Type => Array.of(self)
        field   :Nums,              :Type => Array.of(Number, Object)
        field   :Limits,            :Type => Array.of(Number, length: 2)

        def self.of(klass)
            return Class.new(self) do
                field   :Kids,      :Type => Array.of(self)
                field   :Nums,      :Type => Array.of(Number, klass)
            end
        end
    end

end
