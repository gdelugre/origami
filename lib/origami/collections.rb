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

    class PDF
        #
        # Returns true if the document behaves as a portfolio for embedded files.
        #
        def portfolio?
            self.Catalog.Collection.is_a?(Dictionary)
        end
    end

    class Collection < Dictionary
        include StandardObject
        
        module View
            DETAILS = :D
            TILE    = :T
            HIDDEN  = :H
        end

        class Schema < Dictionary
            include StandardObject

            field   :Type,              :Type => Name, :Default => :CollectionSchema
        end

        class Navigator < Dictionary
            include StandardObject
            
            module Type
                FLEX    = :Module
                FLASH   = :Default
            end

            field   :SWF,               :Type => String, :Required => true
            field   :Name,              :Type => String, :Required => true
            field   :Desc,              :Type => String
            field   :Category,          :Type => String
            field   :ID,                :Type => String, :Required => true
            field   :Version,           :Type => String
            field   :APIVersion,        :Type => String, :Required => true
            field   :LoadType,          :Type => Name, :Default => Type::FLASH
            field   :Icon,              :Type => String
            field   :Locale,            :Type => String
            field   :Strings,           :Type => NameTreeNode.of(String)
            field   :InitialFields,     :Type => Schema
            field   :Resources,         :Type => NameTreeNode.of(Stream), :Required => true
        end

        class Color < Dictionary
            include StandardObject

            field   :Background,        :Type => Array.of(Number, length: 3)
            field   :CardBackground,    :Type => Array.of(Number, length: 3)
            field   :CardBorder,        :Type => Array.of(Number, length: 3)
            field   :PrimaryText,       :Type => Array.of(Number, length: 3)
            field   :SecondaryText,     :Type => Array.of(Number, length: 3)
        end

        class Split < Dictionary
            include StandardObject
            
            HORIZONTAL  = :H
            VERTICAL    = :V
            NONE        = :N

            field   :Direction,         :Type => Name
            field   :Position,          :Type => Number
        end

        class Item < Dictionary
            include StandardObject

            field   :Type,              :Type => Name, :Default => :CollectionItem
        end

        class Subitem < Dictionary
            include StandardObject

            field   :Type,              :Type => Name, :Default => :CollectionSubitem
            field   :D,                 :Type => [ String, Number ]
            field   :P,                 :Type => String
        end

        class Folder < Dictionary
            include StandardObject

            field   :Type,              :Type => Name, :Default => :Folder
            field   :ID,                :Type => Integer, :Required => true
            field   :Name,              :Type => String, :Required => true
            field   :Parent,            :Type => Folder
            field   :Child,             :Type => Folder
            field   :Next,              :Type => Folder
            field   :CI,                :Type => Item
            field   :Desc,              :Type => String
            field   :CreationDate,      :Type => String
            field   :ModDate,           :Type => String
            field   :Thumb,             :Type => Stream
            field   :Free,              :Type => Array.of(Array.of(Integer, length: 2))
        end

        class Sort < Dictionary
            include StandardObject

            field   :Type,              :Type => Name, :Default => :CollectionSort
            field   :S,                 :Type => [ Name, Array.of(Name) ]
            field   :A,                 :Type => [ Boolean, Array.of(Boolean) ]
        end

        #
        # Collection fields.
        #
        field   :Type,              :Type => Name, :Default => :Collection
        field   :Schema,            :Type => Schema
        field   :D,                 :Type => String
        field   :View,              :Type => Name, :Default => View::DETAILS
        field   :Sort,              :Type => Sort
        field   :Navigator,         :Type => Navigator, :ExtensionLevel => 3
        field   :Resources,         :Type => NameTreeNode.of(Stream), :ExtensionLevel => 3
        field   :Colors,            :Type => Color, :ExtensionLevel => 3
        field   :Folders,           :Type => Folder, :ExtensionLevel => 3
        field   :Split,             :Type => Split, :ExtensionLevel => 3
    end
end
