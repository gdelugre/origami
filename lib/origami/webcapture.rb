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

    module WebCapture

        class CommandSettings < Dictionary
            include StandardObject

            field   :G,       :Type => Dictionary
            field   :C,       :Type => Dictionary
        end

        class Command < Dictionary
            include StandardObject

            module Flags
                SAMESITE    = 1 << 1
                SAMEPATH    = 1 << 2
                SUBMIT      = 1 << 3
            end

            field   :URL,       :Type => String, :Required => true
            field   :L,         :Type => Integer, :Default => 1
            field   :F,         :Type => Integer, :Default => 0
            field   :P,         :Type => [ String, Stream ]
            field   :CT,        :Type => String, :Default => "application/x-www-form-urlencoded"
            field   :H,         :Type => String
            field   :S,         :Type => CommandSettings
        end

        class SourceInformation < Dictionary
            include StandardObject

            module SubmissionType
                NOFORM   = 0
                GETFORM  = 1
                POSTFORM = 2
            end

            field   :AU,        :Type => [ String, Dictionary ], :Required => true
            field   :TS,        :Type => String
            field   :E,         :Type => String
            field   :S,         :Type => Integer, :Default => 0
            field   :C,         :Type => Command
        end

        class SpiderInfo < Dictionary
            include StandardObject

            field   :V,         :Type => Real, :Default => 1.0, :Version => "1.3", :Required => true
            field   :C,         :Type => Array.of(Command)
        end

        class ContentSet < Dictionary 
            include StandardObject

            PAGE_SET    = :SPS
            IMAGE_SET   = :SIS

            field   :Type,      :Type => Name, :Default => :SpiderContentSet
            field   :S,         :Type => Name, :Required => true
            field   :ID,        :Type => String, :Required => true
            field   :O,         :Type => Array, :Required => true
            field   :SI,        :Type => [ SourceInformation, Array.of(SourceInformation) ], :Required => true
            field   :CT,        :Type => String
            field   :TS,        :Type => String
        end

        class PageContentSet < ContentSet
            field   :S,         :Type => Name, :Default => ContentSet::PAGE_SET, :Required => true
            field   :T,         :Type => String
            field   :TID,       :Type => String
        end

        class ImageContentSet < ContentSet
            field   :S,         :Type => Name, :Default => ContentSet::IMAGE_SET, :Required => true
            field   :R,         :Type => [ Integer, Array.of(Integer) ], :Required => true
        end
    end

end
