=begin

    This file is part of Origami, PDF manipulation framework for Ruby
    Copyright (C) 2017	Guillaume Delugré.

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

    module OptionalContent

        class Usage < Dictionary
            include StandardObject

            class CreatorInfo < Dictionary
                include StandardObject

                field   :Creator,       :Type => String, :Required => true
                field   :Subtype,       :Type => Name, :Required => true 
            end

            class Language < Dictionary
                include StandardObject

                field   :Lang,          :Type => String, :Required => true
                field   :Preferred,     :Type => Name, :Default => :OFF
            end

            class Export < Dictionary
                include StandardObject

                field   :ExportState,   :Type => Name, :Required => true
            end

            class Zoom < Dictionary
                include StandardObject

                field   :min,           :Type => Real, :Default => 0
                field   :max,           :Type => Real, :Default => Float::INFINITY
            end

            class Print < Dictionary
                include StandardObject

                field   :Subtype,       :Type => Name
                field   :PrintState,    :Type => Name
            end

            class View < Dictionary
                include StandardObject

                field   :ViewState,     :Type => Name, :Required => true
            end

            class User < Dictionary
                include StandardObject

                module Type
                    INDIVIDUAL      = :Ind
                    TITLE           = :Ttl
                    ORGANIZATION    = :Org
                end

                field   :Type,          :Type => Name, :Required => true
                field   :Name,          :Type => [ String, Array.of(String) ], :Required => true
            end

            class PageElement < Dictionary
                include StandardObject

                module Type
                    HEADER_FOOTER   = :HF
                    FOREGROUND      = :FG
                    BACKGROUND      = :BG
                    LOGO            = :L
                end

                field   :Subtype,       :Type => Name, :Required => true
            end

            field   :CreatorInfo,   :Type => CreatorInfo
            field   :Language,      :Type => Language
            field   :Export,        :Type => Export
            field   :Zoom,          :Type => Zoom
            field   :Print,         :Type => Print
            field   :View,          :Type => View
            field   :User,          :Type => User
            field   :PageElement,   :Type => PageElement
        end

        class Group < Dictionary
            include StandardObject

            module Intent
                VIEW    = :View
                DESIGN  = :Design
            end

            field   :Type,      :Type => Name, :Required => true, :Default => :OCG
            field   :Name,      :Type => String, :Required => true
            field   :Intent,    :Type => [ Name, Array.of(Name) ]
            field   :Usage,     :Type => Usage
        end

        class Membership < Dictionary
            include StandardObject

            module Policy
                ALL_ON  = :AllOn
                ANY_ON  = :AnyOn
                ALL_OFF = :AllOff
                ANY_OFF = :AnyOff
            end

            field   :Type,      :Type => Name, :Required => true, :Default => :OCMD
            field   :OCGs,      :Type => [ Group, Array.of(Group) ]
            field   :P,         :Type => Name, :Default => Policy::ANY_ON
            field   :VE,        :Type => Array, :Version => "1.6"
        end

        class UsageApplication < Dictionary
            include StandardObject

            module Event
                VIEW    = :View
                PRINT   = :Print
                EXPORT  = :Export
            end

            field   :Event,     :Type => Name, :Required => true
            field   :OCGs,      :Type => Array.of(Group), :Default => []
            field   :Category,  :Type => Array.of(Name), :Required => true
        end

        class Configuration < Dictionary
            include StandardObject

            module State
                ON          = :On
                OFF         = :Off
                UNCHANGED   = :Unchanged
            end

            module Mode
                ALL_PAGES       = :AllPages
                VISIBLE_PAGES   = :VisiblePages
            end

            field   :Name,      :Type => String
            field   :Creator,   :Type => String
            field   :BaseState, :Type => Name, :Default => State::ON
            field   :ON,        :Type => Array.of(Group)
            field   :OFF,       :Type => Array.of(Group)
            field   :Intent,    :Type => [ Name, Array.of(Name) ]
            field   :AS,        :Type => Array.of(UsageApplication)
            field   :Order,     :Type => Array
            field   :ListMode,  :Type => Name, :Default => Mode::ALL_PAGES
            field   :RBGroups,  :Type => Array.of(Array.of(Group)), :Default => []
            field   :Locked,    :Type => Array.of(Group), :Default => [], :Version => "1.6"
        end

        class Properties < Dictionary
            include StandardObject

            field   :OCGs,      :Type => Array.of(Group), :Required => true
            field   :D,         :Type => Configuration, :Required => true
            field   :Configs,   :Type => Array.of(Configuration)
        end
    end
end
