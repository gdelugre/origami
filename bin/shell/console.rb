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

require 'tempfile'
require 'hexdump'
require 'colorize'

String.disable_colorization(false)

module Origami
    module Object
        def inspect
            to_s
        end
    end

    class Stream
        def edit(editor = ENV['EDITOR'])
            Tempfile.open("origami") do |tmpfile|
                tmpfile.write(self.data)
                tmpfile.flush

                Process.wait Kernel.spawn "#{editor} #{tmpfile.path}"

                self.data = File.read(tmpfile.path)
                tmpfile.unlink
            end

            true
        end

        def inspect
            self.data.hexdump
        end
    end

    class Page < Dictionary
        def edit
            each_content_stream do |stream|
                stream.edit
            end
        end
    end

    class PDF
        if defined?(PDF::JavaScript::Engine)
            class JavaScript::Engine
                def shell
                    loop do
                        print "js > ".magenta
                        break if (line = gets).nil?

                        begin
                            puts exec(line)
                        rescue V8::JSError => e
                            puts "Error: #{e.message}"
                        end
                    end
                end
            end
        end

        class Revision
            def to_s
                puts "----------  Body  ----------".white.bold
                @body.each_value do |obj|
                    print "#{obj.reference.to_s.rjust(8,' ')}".ljust(10).magenta
                    puts "#{obj.type}".yellow
                end

                puts "---------- Trailer ---------".white.bold
                if not @trailer.dictionary
                    puts "  [x] No trailer found.".blue
                else
                    @trailer.dictionary.each_pair do |entry, value|
                        print "  [*] ".magenta
                        print "#{entry}: ".yellow
                        puts "#{value}".red
                    end

                    print "  [+] ".magenta
                    print "startxref: ".yellow
                    puts "#{@trailer.startxref}".red
                end
            end

            def inspect
                to_s
            end
        end

        def to_s
            puts

            puts "---------- Header ----------".white.bold
            print "  [+] ".magenta
            print "Version: ".yellow
            puts "#{@header.major_version}.#{@header.minor_version}".red

            @revisions.each do |revision|
                revision.to_s
            end
            puts
        end

        def inspect
            to_s
        end
    end

end
