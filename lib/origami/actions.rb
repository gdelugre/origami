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
        # Lookup script in the scripts name directory.
        #
        def get_script_by_name(name)
            resolve_name Names::JAVASCRIPT, name
        end

        #
        # Calls block for each named JavaScript script.
        #
        def each_named_script(&b)
            each_name(Names::JAVASCRIPT, &b)
        end
    end

    #
    # Class representing an action to launch in a PDF.
    #
    class Action < Dictionary
        include StandardObject

        field   :Type,    :Type => Name, :Default => :Action
        field   :S,       :Type => Name, :Required => true
        field   :Next,    :Type => [ Array.of(Action), Action ], :Version => "1.2"

        #
        # Class representing a action going to a destination in the current document.
        #
        class GoTo < Action

            field   :S,       :Type => Name, :Default => :GoTo, :Required => true
            field   :D,       :Type => [ Destination, Name, String ], :Required => true

            #
            # Creates a new GoTo Action.
            # _hash_:: A hash of options to set for this jump.
            #
            def self.[](hash = {})
                if hash.is_a? Destination
                    self.new(:S => :GoTo, :D => hash)
                else
                    self.new(hash)
                end
            end
        end

        def self.GoTo(hash = {})
            Action::GoTo[hash]
        end

        #
        # Class representing an action launching an URL.
        #
        class URI < Action

            field   :S,       :Type => Name, :Default => :URI, :Required => true
            field   :URI,     :Type => String, :Required => true
            field   :IsMap,   :Type => Boolean, :Default => false

            #
            # Creates a new URI Action.
            # _uri_:: The URI to launch.
            # _ismap_::
            #
            def self.[](uri, ismap = false)
                self.new(:URI => uri, :IsMap => ismap)
            end
        end

        def self.URI(uri, ismap = false)
            Action::URI[uri, ismap]
        end

        #
        # Class representing a JavaScript Action.
        #
        class JavaScript < Action

            field   :S,       :Type => Name, :Default => :JavaScript, :Required => true
            field   :JS,      :Type => [ Stream, String ], :Required => true

            #
            # Creates a new JavaScript Action.
            # _script_:: The script to be executed.
            #
            def self.[](script)
                self.new(:JS => script)
            end
        end

        def self.JavaScript(script)
            Action::JavaScript[script]
        end

        #
        # Class representing an Action which run a command on the current system.
        #
        class Launch < Action

            #
            # Dictionary for passing parameter to Windows applications during Launch.
            #
            class WindowsLaunchParams < Dictionary
                include StandardObject

                field   :F,         :Type => String, :Required => true
                field   :D,         :Type => String
                field   :O,         :Type => String, :Default => "open"
                field   :P,         :Type => String
            end

            field   :S,         :Type => Name, :Default => :Launch, :Required => true
            field   :F,         :Type => [ String, FileSpec ]
            field   :Win,       :Type => WindowsLaunchParams
            field   :Mac,       :Type => Object
            field   :Unix,      :Type => Object
            field   :NewWindow, :Type => Boolean
        end

        #
        # Class representing a Named Action.
        # Named actions are predefined GoTo actions.
        #
        class Named < Action

            field   :S,         :Type => Name, :Default => :Named, :Required => true
            field   :N,         :Type => Name, :Required => true

            def self.[](type)
                self.new(:N => type)
            end

            NEXT_PAGE = self[:NextPage]
            PREV_PAGE = self[:PrevPage]
            FIRST_PAGE = self[:FirstPage]
            LAST_PAGE = self[:LastPage]
            PRINT = self[:Print]
        end

        def self.Named(type)
            Action::Named[type]
        end

        #
        # Class representing a GoTo Action to an external file.
        #
        class GoToR < Action

            field   :S,         :Type => Name, :Default => :GoToR, :Required => true
            field   :F,         :Type => [ String, FileSpec ], :Required => true
            field   :D,         :Type => [ Destination, Name, String ], :Required => true
            field   :NewWindow, :Type => Boolean, :Version => "1.2"

            #
            # Creates a new GoTo remote Action.
            # _file_:: A FileSpec describing the file.
            # _dest_:: A Destination in the file.
            # _new_window_:: Specifies whether the file has to be opened in a new window.
            #
            def self.[](file, dest: Destination::GlobalFit[0], new_window: false)
                self.new(:F => file, :D => dest, :NewWindow => new_window)
            end
        end

        def self.GoToR(file, dest: Destination::GlobalFit[0], new_window: false)
            Action::GoToR[file, dest: dest, new_window: new_window]
        end

        #
        # Class representing a GoTo Action to an embedded pdf file.
        #
        class GoToE < Action

            #
            # A class representing a target for a GoToE to an embedded file.
            #
            class EmbeddedTarget < Dictionary
                include StandardObject

                module Relationship
                    PARENT = :P
                    CHILD = :C
                end

                field   :R,           :Type => Name, :Required => true
                field   :N,           :Type => String
                field   :P,           :Type => [ Integer, String ]
                field   :A,           :Type => [ Integer, String ]
                field   :T,           :Type => Dictionary
            end

            field   :S,         :Type => Name, :Default => :GoToE, :Required => true
            field   :F,         :Type => [ String, FileSpec ]
            field   :D,         :Type => [ Destination, Name, String ], :Required => true
            field   :NewWindow, :Type => Boolean
            field   :T,         :Type => EmbeddedTarget

            def self.[](filename, dest: Destination::GlobalFit[0], new_window: false)
                self.new(:T => EmbeddedTarget.new(:R => :C, :N => filename), :D => dest, :NewWindow => new_window)
            end
        end

        def self.GoToE(filename, dest: Destination::GlobalFit[0], new_window: false)
            Action::GoToE[filename, dest: dest, new_window: new_window]
        end

        #
        # Class representing a SubmitForm action.
        #
        class SubmitForm < Action
            module Flags
                INCLUDEEXCLUDE       = 1 << 0
                INCLUDENOVALUEFIELDS = 1 << 1
                EXPORTFORMAT         = 1 << 2
                GETMETHOD            = 1 << 3
                SUBMITCOORDINATES    = 1 << 4
                XFDF                 = 1 << 5
                INCLUDEAPPENDSAVES   = 1 << 6
                INCLUDEANNOTATIONS   = 1 << 7
                SUBMITPDF            = 1 << 8
                CANONICALFORMAT      = 1 << 9
                EXCLNONUSERANNOTS    = 1 << 10
                EXCLFKEY             = 1 << 11
                EMBEDFORM            = 1 << 12
            end

            field   :S,           :Type => Name, :Default => :SubmitForm, :Required => true
            field   :F,           :Type => FileSpec
            field   :Fields,      :Type => Array
            field   :Flags,       :Type => Integer, :Default => 0

            def self.[](url, fields = [], flags = 0)
                url = FileSpec.new(:FS => :URL, :F => url) unless url.is_a? FileSpec
                self.new(:F => url, :Fields => fields, :Flags => flags)
            end
        end

        def self.SubmitForm(url, fields = [], flags = 0)
            Action::SubmitForm[url, fields, flags]
        end

        class ImportData < Action

            field   :S,           :Type => Name, :Default => :ImportData, :Required => true
            field   :F,           :Type => Dictionary, :Required => true

            def self.[](file)
                file = FileSpec.new(:FS => :File, :F => file) unless file.is_a? FileSpec
                self.new(:F => file)
            end
        end

        def self.ImportData(file)
            Action::ImportData[file]
        end

        class RichMediaExecute < Action

            class Command < Dictionary
                include StandardObject

                field   :Type,      :Type => Name, :Default => :RichMediaCommand, :Version => "1.7", :ExtensionLevel => 3
                field   :C,         :Type => String, :Version => "1.7", :ExtensionLevel => 3, :Required => true
                field   :A,         :Type => Object, :Version => "1.7", :ExtensionLevel => 3
            end

            field   :S,           :Type => Name, :Default => :RichMediaExecute, :Version => "1.7", :ExtensionLevel => 3, :Required => true
            field   :TA,          :Type => Annotation::RichMedia, :Version => "1.7", :ExtensionLevel => 3, :Required => true
            field   :TI,          :Type => Annotation::RichMedia::Instance, :Version => "1.7", :ExtensionLevel => 3
            field   :CMD,         :Type => Command, :Version => "1.7", :ExtensionLevel => 3, :Required => true

            def self.[](annotation, command, *params)
                self.new(:TA => annotation, :CMD => Command.new(:C => command, :A => params))
            end
        end

        def self.RichMediaExecute(annotation, command, *params)
            Action::RichMediaExecute[annotation, command, *params]
        end

        class SetOCGState < Action

            module State
                ON      = :ON
                OFF     = :OFF
                TOGGLE  = :Toggle
            end

            field   :S,             :Type => Name, :Default => :SetOCGState, :Required => true
            field   :State,         :Type => Array.of([Name, OptionalContent::Group]), :Required => true
            field   :PreserveRB,    :Type => Boolean, :Default => true
        end
    end

end
