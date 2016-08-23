=begin

    This file is part of Origami, PDF manipulation framework for Ruby
    Copyright (C) 2016	Guillaume Delugré.

    Origami is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Origami is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Origami.  If not, see <http://www.gnu.org/licenses/>.

=end

require 'colorize'

class String #:nodoc:

    def hexdump(bytesperline: 16, upcase: true, offsets: true, delta: 0)
        dump = ""
        counter = 0
    
        while counter < self.length
            offset = sprintf("%010X", counter + delta)
      
            linelen = [ self.length - counter, bytesperline ].min
            bytes = ""
            linelen.times do |i|
                byte = self[counter + i].ord.to_s(16).rjust(2, '0')

                bytes << byte
                bytes << " " unless i == bytesperline - 1
            end

            ascii = self[counter, linelen].ascii_print
      
            if upcase
                offset.upcase!
                bytes.upcase!
            end
      
            dump << "#{offset.yellow if offsets}  #{bytes.to_s.ljust(bytesperline * 3 - 1).bold}  #{ascii}\n"

            counter += bytesperline
        end

        dump
    end
  
    def ascii_print
        self.gsub(/[^[[:print:]]]/, ".")
    end
end
