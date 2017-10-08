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

    # Forward declaration.
    class Action < Dictionary; end

    #
    # Class representing an annotation.
    # Annotations are objects which user can interact with.
    #
    class Annotation < Dictionary
        include StandardObject
        
        #
        # An AppearanceStream is a FormXObject.
        #
        class AppearanceStream < Graphics::FormXObject ; end
    
        #
        # Appearance Dictionary of an Annotation.
        #
        class AppearanceDictionary < Dictionary
            include StandardObject

            field   :N,               :Type => [ AppearanceStream, Dictionary ], :Required => true
            field   :R,               :Type => [ AppearanceStream, Dictionary ]
            field   :D,               :Type => [ AppearanceStream, Dictionary ]
        end

        #
        # Class representing additional actions which can be associated with an annotation having an AA field.
        #
        class AdditionalActions < Dictionary
            include StandardObject
          
            field   :E,             :Type => Action, :Version => "1.2" # Mouse Enter
            field   :X,             :Type => Action, :Version => "1.2" # Mouse Exit
            field   :D,             :Type => Action, :Version => "1.2" # Mouse Down
            field   :U,             :Type => Action, :Version => "1.2" # Mouse Up
            field   :Fo,            :Type => Action, :Version => "1.2" # Focus
            field   :Bl,            :Type => Action, :Version => "1.2" # Blur
            field   :PO,            :Type => Action, :Version => "1.2" # Page Open
            field   :PC,            :Type => Action, :Version => "1.2" # Page Close
            field   :PV,            :Type => Action, :Version => "1.2" # Page Visible
            field   :PI,            :Type => Action, :Version => "1.2" # Page Invisible
        end

        #
        # Annotation fields.
        #
        field   :Type,            :Type => Name, :Default => :Annot
        field   :Subtype,         :Type => Name, :Required => true
        field   :Rect,            :Type => Rectangle, :Default => [ 0, 0, 0, 0 ], :Required => true
        field   :Contents,        :Type => String
        field   :P,               :Type => Page, :Version => "1.3"
        field   :NM,              :Type => String, :Version => "1.4"
        field   :M,               :Type => String, :Version => "1.1"
        field   :F,               :Type => Integer, :Default => 0, :Version => "1.1"
        field   :AP,              :Type => AppearanceDictionary, :Version => "1.2"
        field   :AS,              :Type => Name, :Version => "1.2"
        field   :Border,          :Type => Array, :Default => [ 0 , 0 , 1 ]
        field   :C,               :Type => Array.of(Number), :Version => "1.1"
        field   :StructParent,    :Type => Integer, :Version => "1.3"
        field   :OC,              :Type => Dictionary, :Version => "1.5"

        def set_normal_appearance(apstm)
            self.AP ||= AppearanceDictionary.new
            self.AP[:N] = apstm

            self
        end

        def set_rollover_appearance(apstm)
            self.AP ||= AppearanceDictionary.new
            self.AP[:R] = apstm

            self
        end

        def set_down_appearance(apstm)
            self.AP ||= AppearanceStream.new
            self.AP[:D] = apstm

            self
        end

        module Triggerable
          
            def onMouseOver(action)        
                self.AA ||= AdditionalActions.new
                self.AA.E = action
            end
          
            def onMouseOut(action)        
                self.AA ||= AdditionalActions.new
                self.AA.X = action
            end
          
            def onMouseDown(action)        
                self.AA ||= AdditionalActions.new
                self.AA.D = action
            end
          
            def onMouseUp(action)        
                self.AA ||= AdditionalActions.new
                self.AA.U = action
            end
          
            def onFocus(action)        
                self.AA ||= AdditionalActions.new
                self.AA.Fo = action
            end
          
            def onBlur(action)        
                self.AA ||= AdditionalActions.new
                self.AA.Bl = action
            end
          
            def onPageOpen(action)        
                self.AA ||= AdditionalActions.new
                self.AA.PO = action
            end
          
            def onPageClose(action)        
                self.AA ||= AdditionalActions.new
                self.AA.PC = action
            end

            def onPageVisible(action)        
                self.AA ||= AdditionalActions.new
                self.AA.PV = action
            end
          
            def onPageInvisible(action)        
                self.AA ||= AdditionalActions.new
                self.AA.PI = action
            end
        end
    
        #
        # Annotation flags
        #
        module Flags
            INVISIBLE       = 1 << 0
            HIDDEN          = 1 << 1
            PRINT           = 1 << 2
            NOZOOM          = 1 << 3
            NOROTATE        = 1 << 4
            NOVIEW          = 1 << 5
            READONLY        = 1 << 6
            LOCKED          = 1 << 7
            TOGGLENOVIEW    = 1 << 8
            LOCKEDCONTENTS  = 1 << 9
        end

        module Markup
            def self.included(receiver)
                receiver.field    :T,             :Type => String, :Version => "1.1"
                receiver.field    :Popup,         :Type => Dictionary, :Version => "1.3"
                receiver.field    :CA,            :Type => Number, :Default => 1.0, :Version => "1.4"
                receiver.field    :RC,            :Type => [String, Stream], :Version => "1.5"
                receiver.field    :CreationDate,  :Type => String, :Version => "1.5"
                receiver.field    :IRT,           :Type => Dictionary, :Version => "1.5"
                receiver.field    :Subj,          :Type => String, :Version  => "1.5"
                receiver.field    :RT,            :Type => Name, :Default => :R, :Version => "1.6"
                receiver.field    :IT,            :Type => Name, :Version => "1.6"
                receiver.field    :ExData,        :Type => Dictionary, :Version => "1.7"
            end
        end

        class BorderStyle < Dictionary
            include StandardObject
      
            SOLID       = :S
            DASHED      = :D
            BEVELED     = :B
            INSET       = :I
            UNDERLINE   = :U

            field   :Type,            :Type => Name, :Default => :Border
            field   :W,               :Type => Number, :Default => 1
            field   :S,               :Type => Name, :Default => SOLID
            field   :D,               :Type => Array, :Default => [ 3 ]
        end

        class BorderEffect < Dictionary
            include StandardObject

            NONE    = :S
            CLOUDY  = :C

            field   :S,               :Type => Name, :Default => NONE
            field   :I,               :Type => Integer, :Default => 0
        end
    
        class AppearanceCharacteristics < Dictionary
            include StandardObject
          
            module CaptionStyle
                CAPTION_ONLY     = 0
                ICON_ONLY        = 1
                CAPTION_BELOW    = 2
                CAPTION_ABOVE    = 3
                CAPTION_RIGHT    = 4
                CAPTION_LEFT     = 5
                CAPTION_OVERLAID = 6
            end
        
            field   :R,               :Type => Integer, :Default => 0
            field   :BC,              :Type => Array.of(Number)
            field   :BG,              :Type => Array.of(Number)
            field   :CA,              :Type => String
            field   :RC,              :Type => String
            field   :AC,              :Type => String
            field   :I,               :Type => Stream
            field   :RI,              :Type => Stream
            field   :IX,              :Type => Stream
            field   :IF,              :Type => Dictionary
            field   :TP,              :Type => Integer, :Default => CaptionStyle::CAPTION_ONLY
        end
    
        class Shape < Annotation
            include Markup

            field   :Subtype,         :Type => Name, :Required => true
            field   :BS,              :Type => BorderStyle 
            field   :IC,              :Type => Array.of(Number)
            field   :BE,              :Type => BorderEffect, :Version => "1.5"
            field   :RD,              :Type => Rectangle, :Version => "1.5"
        end
    
        class Square < Shape
            field   :Subtype,         :Type => Name, :Default => :Square, :Required => true
        end
    
        class Circle < Shape
            field   :Subtype,         :Type => Name, :Default => :Circle, :Required => true
        end

        #
        # Text annotation
        #
        class Text < Annotation
            include Markup

            module TextName
                COMMENT      = :C
                KEY          = :K
                NOTE         = :N
                HELP         = :H
                NEWPARAGRAPH = :NP
                PARAGRAPH    = :P
                INSERT       = :I
            end

            field   :Subtype,         :Type => Name, :Default => :Text, :Required => true
            field   :Open,            :Type => Boolean, :Default => false
            field   :Name,            :Type => Name, :Default => TextName::NOTE
            field   :State,           :Type => String, :Version => "1.5"
            field   :StateModel,      :Type => String, :Version => "1.5"

            def pre_build
                model = self.StateModel
                state = self.State
                
                case model
                when "Marked"
                    self.State = "Unmarked" if state.nil?
                when "Review"
                    self.State = "None" if state.nil?
                end

                super
            end
        end

        #
        # FreeText Annotation
        #
        class FreeText < Annotation
            include Markup

            module Intent
                FREETEXT            = :FreeText
                FREETEXTCALLOUT     = :FreeTextCallout
                FREETEXTTYPEWRITER  = :FreeTextTypeWriter
            end

            field   :Subtype,         :Type => Name, :Default => :FreeText, :Required => true
            field   :DA,              :Type => String, :Default => "/F1 10 Tf 0 g", :Required => true
            field   :Q,               :Type => Integer, :Default => Field::TextAlign::LEFT, :Version => "1.4"
            field   :RC,              :Type => [String, Stream], :Version => "1.5"
            field   :DS,              :Type => String, :Version => "1.5"
            field   :CL,              :Type => Array.of(Number), :Version => "1.6"
            field   :IT,              :Type => Name, :Default => Intent::FREETEXT, :Version => "1.6"
            field   :BE,              :Type => BorderEffect, :Version => "1.6"
            field   :RD,              :Type => Rectangle, :Version => "1.6"
            field   :BS,              :Type => BorderStyle, :Version => "1.6"
            field   :LE,              :Type => Name, :Default => :None, :Version => "1.6"
        end
    
        #
        # Class representing an link annotation.
        #
        class Link < Annotation
          
            #
            # The annotations highlighting mode.
            # The visual effect to be used when the mouse button is pressed or held down inside its active area.
            #
            module Highlight
                # No highlighting
                NONE = :N
                
                # Invert the contents of the annotation rectangle. 
                INVERT = :I
                
                # Invert the annotations border. 
                OUTLINE = :O
                
                # Display the annotation as if it were being pushed below the surface of the page
                PUSH = :P
            end

            field   :Subtype,             :Type => Name, :Default => :Link, :Required => true
            field   :A,                   :Type => Action, :Version => "1.1"
            field   :Dest,                :Type => [ Destination, Name, String ]
            field   :H,                   :Type => Name, :Default => Highlight::INVERT, :Version => "1.2"
            field   :PA,                  :Type => Dictionary, :Version => "1.3"
            field   :QuadPoints,          :Type => Array.of(Number), :Version => "1.6"
            field   :BS,                  :Type => BorderStyle, :Version => "1.6"
        end
    
        #
        # Class representing a file attachment annotation.
        #
        class FileAttachment < Annotation
            include Markup

            # Icons to be displayed for file attachment.
            module Icons
                GRAPH       = :Graph
                PAPERCLIP   = :Paperclip
                PUSHPIN     = :PushPin
                TAG         = :Tag
            end

            field   :Subtype,             :Type => Name, :Default => :FileAttachment, :Required => true
            field   :FS,                  :Type => FileSpec, :Required => true
            field   :Name,                :Type => Name, :Default => Icons::PUSHPIN
        end
    
        #
        # Class representing a screen Annotation.
        # A screen annotation specifies a region of a page upon which media clips may be played. It also serves as an object from which actions can be triggered.
        #
        class Screen < Annotation
            include Triggerable

            field   :Subtype,             :Type => Name, :Default => :Screen, :Required => true
            field   :T,                   :Type => String
            field   :MK,                  :Type => AppearanceCharacteristics
            field   :A,                   :Type => Action, :Version => "1.1"
            field   :AA,                  :Type => AdditionalActions, :Version => "1.2"
        end

        class Sound < Annotation
            include Markup
          
            module Icons
                SPEAKER = :Speaker
                MIC     = :Mic
            end

            field   :Subtype,             :Type => Name, :Default => :Sound, :Required => true
            field   :Sound,               :Type => Stream, :Required => true
            field   :Name,                :Type => Name, :Default => Icons::SPEAKER
        end

        class RichMedia < Annotation
          
            class Position < Dictionary
                include StandardObject

                NEAR    = :Near
                CENTER  = :Center
                FAR     = :Far
                
                field   :Type,              :Type => Name, :Default => :RichMediaPosition, :Version => "1.7", :ExtensionLevel => 3 
                field   :HAlign,            :Type => Name, :Default => FAR, :Version => "1.7", :ExtensionLevel => 3 
                field   :VAlign,            :Type => Name, :Default => NEAR, :Version => "1.7", :ExtensionLevel => 3 
                field   :HOffset,           :Type => Number, :Default => 18, :Version => "1.7", :ExtensionLevel => 3 
                field   :VOffset,           :Type => Number, :Default => 18, :Version => "1.7", :ExtensionLevel => 3 
            end

            class Window < Dictionary
                include StandardObject

                field   :Type,              :Type => Name, :Default => :RichMediaWindow, :Version => "1.7", :ExtensionLevel => 3 
                field   :Width,             :Type => Dictionary, :Default => {:Default => 288, :Max => 576, :Min => 72}, :Version => "1.7", :ExtensionLevel => 3
                field   :Height,            :Type => Dictionary, :Default => {:Default => 216, :Max => 432, :Min => 72}, :Version => "1.7", :ExtensionLevel => 3
                field   :Position,          :Type => Position, :Version => "1.7", :ExtensionLevel => 3  
            end

            class Presentation < Dictionary
                include StandardObject

                WINDOWED = :Windowed
                EMBEDDED = :Embedded

                field   :Type,              :Type => Name, :Default => :RichMediaPresentation, :Version => "1.7", :ExtensionLevel => 3
                field   :Style,             :Type => Name, :Default => EMBEDDED, :Version => "1.7", :ExtensionLevel => 3
                field   :Window,            :Type => Window, :Version => "1.7", :ExtensionLevel => 3
                field   :Transparent,       :Type => Boolean, :Default => false, :Version => "1.7", :ExtensionLevel => 3
                field   :NavigationPane,    :Type => Boolean, :Default => false, :Version => "1.7", :ExtensionLevel => 3
                field   :Toolbar,           :Type => Boolean, :Version => "1.7", :ExtensionLevel => 3
                field   :PassContextClick,  :Type => Boolean, :Default => false, :Version => "1.7", :ExtensionLevel => 3
            end

            class Animation < Dictionary
                include StandardObject

                NONE          = :None
                LINEAR        = :Linear
                OSCILLATING   = :Oscillating

                field   :Type,              :Type => Name, :Default => :RichMediaAnimation, :Version => "1.7", :ExtensionLevel => 3
                field   :Subtype,           :Type => Name, :Default => NONE, :Version => "1.7", :ExtensionLevel => 3
                field   :PlayCount,         :Type => Integer, :Default => -1, :Version => "1.7", :ExtensionLevel => 3
                field   :Speed,             :Type => Number, :Default => 1, :Version => "1.7", :ExtensionLevel => 3
            end

            class Activation < Dictionary
                include StandardObject

                USER_ACTION   = :XA
                PAGE_OPEN     = :PO
                PAGE_VISIBLE  = :PV

                field   :Type,              :Type => Name, :Default => :RichMediaActivation, :Version => "1.7", :ExtensionLevel => 3
                field   :Condition,         :Type => Name, :Default => USER_ACTION, :Version  => "1.7", :ExtensionLevel => 3
                field   :Animation,         :Type => Animation, :Version => "1.7", :ExtensionLevel => 3
                field   :View,              :Type => Dictionary, :Version => "1.7", :ExtensionLevel => 3
                field   :Configuration,     :Type => Dictionary, :Version => "1.7", :ExtensionLevel => 3
                field   :Presentation,      :Type => Presentation, :Version => "1.7", :ExtensionLevel => 3
                field   :Scripts,           :Type => Array.of(FileSpec), :Version => "1.7", :ExtensionLevel => 3
            end

            class Deactivation < Dictionary
                include StandardObject

                USER_ACTION     = :XD
                PAGE_CLOSE      = :PC
                PAGE_INVISIBLE  = :PV

                field   :Type,              :Type => Name, :Default => :RichMediaDeactivation, :Version => "1.7", :ExtensionLevel => 3
                field   :Condition,         :Type => Name, :Default => USER_ACTION, :Version => "1.7", :ExtensionLevel => 3
            end

            class Settings < Dictionary
                include StandardObject

                field   :Type,              :Type => Name, :Default => :RichMediaSettings, :Version => "1.7", :ExtensionLevel => 3
                field   :Activation,        :Type => Activation, :Version => "1.7", :ExtensionLevel => 3
                field   :Deactivation,      :Type => Deactivation, :Version => "1.7", :ExtensionLevel => 3
            end
          
            class CuePoint < Dictionary
                include StandardObject

                NAVIGATION  = :Navigation
                EVENT       = :Event

                field   :Type,              :Type => Name, :Default => :CuePoint, :Version => "1.7", :ExtensionLevel => 3 
                field   :Subtype,           :Type => Name, :Version => "1.7", :ExtensionLevel => 3 
                field   :Name,              :Type => String, :Version => "1.7", :ExtensionLevel => 3, :Required => true
                field   :Time,              :Type => Number, :Version => "1.7", :ExtensionLevel => 3, :Required => true
                field   :A,                 :Type => Action, :Version => "1.7", :ExtensionLevel => 3, :Required => true
            end

            class Parameters < Dictionary
                include StandardObject

                module Binding
                  NONE        = :None
                  FOREGROUND  = :Foreground
                  BACKGROUND  = :Background
                  MATERIAL    = :Material
                end

                field   :Type,              :Type => Name, :Default => :RichMediaParams, :Version => "1.7", :ExtensionLevel => 3 
                field   :FlashVars,         :Type => [String, Stream], :Version => "1.7", :ExtensionLevel => 3  
                field   :Binding,           :Type => Name, :Default => Binding::NONE, :Version => "1.7", :ExtensionLevel => 3 
                field   :BindingMaterialName, :Type => String, :Version => "1.7", :ExtensionLevel => 3 
                field   :CuePoints,         :Type => Array.of(CuePoint), :Default => [], :Version => "1.7", :ExtensionLevel => 3  
                field   :Settings,          :Type => [String, Stream], :Version => "1.7", :ExtensionLevel => 3  
            end

            class Instance < Dictionary
                include StandardObject

                U3D     = :"3D"
                FLASH   = :Flash
                SOUND   = :Sound
                VIDEO   = :Video
                
                field   :Type,              :Type => Name, :Default => :RichMediaInstance, :Version => "1.7", :ExtensionLevel => 3 
                field   :Subtype,           :Type => Name, :Version => "1.7", :ExtensionLevel => 3 
                field   :Params,            :Type => Parameters, :Version => "1.7", :ExtensionLevel => 3 
                field   :Asset,             :Type => FileSpec, :Version => "1.7", :ExtensionLevel => 3 
            end

            class Configuration < Dictionary
                include StandardObject

                U3D     = :"3D"
                FLASH   = :Flash
                SOUND   = :Sound
                VIDEO   = :Video

                field   :Type,              :Type => Name, :Default => :RichMediaConfiguration, :Version => "1.7", :ExtensionLevel => 3 
                field   :Subtype,           :Type => Name, :Version => "1.7", :ExtensionLevel => 3 
                field   :Name,              :Type => String, :Version => "1.7", :ExtensionLevel => 3 
                field   :Instances,         :Type => Array.of(Instance), :Version => "1.7", :ExtensionLevel => 3 
            end

            class Content < Dictionary
                include StandardObject

                field   :Type,              :Type => Name, :Default => :RichMediaContent, :Version => "1.7", :ExtensionLevel => 3 
                field   :Assets,            :Type => Dictionary, :Version => "1.7", :ExtensionLevel => 3 
                field   :Configurations,    :Type => Array.of(Configuration), :Version => "1.7", :ExtensionLevel => 3 
                field   :Views,             :Type => Array, :Version => "1.7", :ExtensionLevel => 3 
            end

            #
            # Fields of the RichMedia Annotation.
            #
            field   :Subtype,               :Type => Name, :Default => :RichMedia, :Version => "1.7", :ExtensionLevel => 3, :Required => true
            field   :RichMediaSettings,     :Type => Settings, :Version => "1.7", :ExtensionLevel => 3
            field   :RichMediaContent,      :Type => Content, :Version => "1.7", :ExtensionLevel => 3, :Required => true
        end

        # Added in ExtensionLevel 3.
        class Projection < Annotation; end
    
        #
        # Class representing a widget Annotation.
        # Interactive forms use widget annotations to represent the appearance of fields and to manage user interactions. 
        #
        class Widget < Annotation
            include Field
            include Triggerable
     
            module Highlight
                # No highlighting
                NONE    = :N
                
                # Invert the contents of the annotation rectangle. 
                INVERT  = :I
                
                # Invert the annotations border. 
                OUTLINE = :O
                
                # Display the annotation as if it were being pushed below the surface of the page
                PUSH    = :P
                
                # Same as P.
                TOGGLE  = :T
            end
      
            field   :Subtype,           :Type => Name, :Default => :Widget, :Required => true
            field   :H,                 :Type => Name, :Default => Highlight::INVERT
            field   :MK,                :Type => AppearanceCharacteristics
            field   :A,                 :Type => Action, :Version => "1.1"
            field   :AA,                :Type => AdditionalActions, :Version => "1.2"
            field   :BS,                :Type => BorderStyle, :Version => "1.2"
          
            def onActivate(action)        
                unless action.is_a?(Action)
                    raise TypeError, "An Action object must be passed."
                end
                
                self.A = action
            end
        
            class Button < Widget
            
                module Flags
                  NOTOGGLETOOFF     = 1 << 14
                  RADIO             = 1 << 15
                  PUSHBUTTON        = 1 << 16
                  RADIOSINUNISON    = 1 << 26
                end
           
                field   :FT,                :Type => Name, :Default => Field::Type::BUTTON, :Required => true
            end
          
            class PushButton < Button
            
                def pre_build
                    self.Ff ||= 0
                    self.Ff |= Button::Flags::PUSHBUTTON
                  
                    super
                end
            end
          
            class CheckBox < Button
            
                def pre_build
                    self.Ff ||= 0
                  
                    self.Ff &= ~Button::Flags::RADIO
                    self.Ff &= ~Button::Flags::PUSHBUTTON
                  
                    super
                end
            end
          
            class Radio < Button
            
                def pre_build
                    self.Ff ||= 0
                  
                    self.Ff &= ~Button::Flags::PUSHBUTTON
                    self.Ff |= Button::Flags::RADIO
                  
                    super
                end
            end
          
            class Text < Widget
                module Flags
                    MULTILINE       = 1 << 12
                    PASSWORD        = 1 << 13
                    FILESELECT      = 1 << 20
                    DONOTSPELLCHECK = 1 << 22
                    DONOTSCROLL     = 1 << 23
                    COMB            = 1 << 24
                    RICHTEXT        = 1 << 25
                end
            
                field   :FT,          :Type => Name, :Default => Field::Type::TEXT, :Required => true
                field   :MaxLen,      :Type => Integer
            end
          
            class Choice < Widget
                module Flags
                    COMBO             = 1 << 17
                    EDIT              = 1 << 18
                    SORT              = 1 << 19
                    MULTISELECT       = 1 << 21
                    DONOTSPELLCHECK   = 1 << 22
                    COMMITONSELCHANGE = 1 << 26
                end

                field   :FT,          :Type => Name, :Default => Field::Type::CHOICE, :Required => true
                field   :Opt,         :Type => Array
                field   :TI,          :Type => Integer, :Default => 0
                field   :I,           :Type => Array, :Version => "1.4"
            end
          
            class ComboBox < Choice
            
                def pre_build
                    self.Ff ||= 0
                    self.Ff |= Choice::Flags::COMBO
                  
                    super
                end
            end
          
            class ListBox < Choice
            
                def pre_build
                    self.Ff ||= 0
                    self.Ff &= ~Choice::Flags::COMBO 
                  
                    super
                end
            end
          
            class Signature < Widget
                field   :FT,          :Type => Name, :Default => Field::Type::SIGNATURE
                field   :Lock,        :Type => SignatureLock, :Version => "1.5"
                field   :SV,          :Type => SignatureSeedValue, :Version => "1.5"
            end
        end
    end

end
