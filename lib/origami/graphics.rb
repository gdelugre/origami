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
        #
        # Common graphics Exception class for errors.
        #
        class Error < Origami::Error; end
    end
end

require 'origami/graphics/instruction'
require 'origami/graphics/state'
require 'origami/graphics/colors'
require 'origami/graphics/path'
require 'origami/graphics/xobject'
require 'origami/graphics/text'
require 'origami/graphics/patterns'
require 'origami/graphics/render'
