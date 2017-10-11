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

    #
    # Common Exception class for Origami errors.
    #
    class Error < StandardError
    end
  
    #
    # Global options for Origami.
    #
    OPTIONS = 
    {
        enable_type_checking: true,      # set to false to disable type consistency checks during compilation.
        enable_type_guessing: true,      # set to false to prevent the parser to guess the type of special dictionary and streams (not recommended).
        enable_type_propagation: true,   # set to false to prevent the parser to propagate type from parents to children.
        ignore_bad_references: false,    # set to interpret invalid references as Null objects, instead of raising an exception.
        ignore_zlib_errors: false,       # set to true to ignore exceptions on invalid Flate streams.
        ignore_png_errors: false,        # set to true to ignore exceptions on invalid PNG predictors.
    }

    autoload :FDF, 'origami/extensions/fdf'
    autoload :PPKLite, 'origami/extensions/ppklite'
end

require 'origami/version'
require 'origami/pdf'
