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

    module Obfuscator
        using TypeConversion

        WHITECHARS = [ " ", "\t", "\r", "\n", "\0" ]
        OBJECTS = [ Array, Boolean, Dictionary, Integer, Name, Null, Stream, String, Real, Reference ]
        MAX_INT = 0xFFFFFFFF
        PRINTABLE = ("!".."9").to_a + (':'..'Z').to_a + ('['..'z').to_a + ('{'..'~').to_a
        FILTERS = [ :FlateDecode, :RunLengthDecode, :LZWDecode, :ASCIIHexDecode, :ASCII85Decode ]

        def self.junk_spaces(max_size = 3)
            length = rand(max_size) + 1

            ::Array.new(length) { WHITECHARS[rand(WHITECHARS.size)] }.join
        end

        def self.junk_comment(max_size = 15)
            length = rand(max_size) + 1

            junk_comment = ::Array.new(length) {
                byte = rand(256).chr until (not byte.nil? and byte != "\n" and byte != "\r"); byte
            }.join

            "%#{junk_comment}#{$/}"
        end

        def self.junk_object(type = nil)
            if type.nil?
                type = OBJECTS[rand(OBJECTS.size)]
            end

            unless type.include?(Origami::Object)
                raise TypeError, "Not a valid object type"
            end

            Obfuscator.send("junk_#{type.to_s.split('::').last.downcase}")
        end

        def self.junk_array(max_size = 5)
            length = rand(max_size) + 1

            ::Array.new(length) {
                obj = Obfuscator.junk_object until (not obj.nil? and not obj.is_a?(Stream)) ; obj
            }.to_o
        end

        def self.junk_boolean
            Boolean.new(rand(2).zero?)
        end

        def self.junk_dictionary(max_size = 5)
            length = rand(max_size) + 1

            hash = Hash.new
            length.times do
                obj = Obfuscator.junk_object
                hash[Obfuscator.junk_name] = obj unless obj.is_a?(Stream)
            end

            hash.to_o
        end

        def self.junk_integer(max = MAX_INT)
            Integer.new(rand(max + 1))
        end

        def self.junk_name(max_size = 8)
            length = rand(max_size) + 1

            Name.new(::Array.new(length) { PRINTABLE[rand(PRINTABLE.size)] }.join)
        end

        def self.junk_null
            Null.new
        end

        def self.junk_stream(max_data_size = 200)

            chainlen = rand(2) + 1
            chain = ::Array.new(chainlen) { FILTERS[rand(FILTERS.size)] }

            length = rand(max_data_size) + 1
            junk_data = ::Array.new(length) { rand(256).chr }.join

            stm = Stream.new
            stm.dictionary = Obfuscator.junk_dictionary(5)
            stm.setFilter(chain)
            stm.data = junk_data

            stm
        end

        def self.junk_string(max_size = 10)
            length = rand(max_size) + 1

            strtype = (rand(2).zero?) ? LiteralString : HexaString

            strtype.new(::Array.new(length) { PRINTABLE[rand(PRINTABLE.size)] }.join)
        end

        def self.junk_real
            Real.new(rand * rand(MAX_INT + 1))
        end

        def self.junk_reference(max_no = 300, max_gen = 1)
            no = rand(max_no) + 1
            gen = rand(max_gen)

            Reference.new(no, gen)
        end
    end

    class Dictionary

        def to_obfuscated_str
            content = TOKENS.first + Obfuscator.junk_spaces
            self.each_pair do |key, value|
                content << Obfuscator.junk_spaces +
                  key.to_obfuscated_str + Obfuscator.junk_spaces +
                  value.to_obfuscated_str + Obfuscator.junk_spaces
            end

            content << TOKENS.last
            super(content)
        end
    end

    module Object
        alias :to_obfuscated_str :to_s
    end

    class Array
        def to_obfuscated_str
            content = TOKENS.first + Obfuscator.junk_spaces
            self.each do |entry|
                content << entry.to_o.to_obfuscated_str + Obfuscator.junk_spaces
            end

            content << TOKENS.last

            super(content)
        end
    end

    class Null
        alias :to_obfuscated_str :to_s
    end

    class Boolean
        alias :to_obfuscated_str :to_s
    end

    class Integer
        alias :to_obfuscated_str :to_s
    end

    class Real
        alias :to_obfuscated_str :to_s
    end

    class Reference
        def to_obfuscated_str
            refstr = refno.to_s + Obfuscator.junk_spaces + refgen.to_s + Obfuscator.junk_spaces + "R"

            super(refstr)
        end
    end

    class LiteralString
        alias :to_obfuscated_str :to_s
    end

    class HexaString
        alias :to_obfuscated_str :to_s
    end

    class Name
        def to_obfuscated_str(prop = 2)
            name = @value.dup

            forbiddenchars = [ " ","#","\t","\r","\n","\0","[","]","<",">","(",")","%","/","\\" ]

            name.gsub!(/./) do |c|
                if rand(prop) == 0 or forbiddenchars.include?(c)
                    hexchar = c.ord.to_s(16)
                    hexchar = "0" + hexchar if hexchar.length < 2

                    '#' + hexchar
                else
                    c
                end
            end

            super(TOKENS.first + name)
        end
    end

    class Stream
        def to_obfuscated_str
            content = ""

            content << @dictionary.to_obfuscated_str
            content << "stream" + $/
            content << self.encoded_data
            content << $/ << TOKENS.last

            super(content)
        end
    end

    class Trailer
        def to_obfuscated_str
            content = ""
            if self.dictionary?
                content << TOKENS.first << $/ << @dictionary.to_obfuscated_str << $/
            end

            content << XREF_TOKEN << $/ << @startxref.to_s << $/ << TOKENS.last << $/

            content
        end
    end

end
