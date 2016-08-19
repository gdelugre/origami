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

    class Projection3D < Dictionary
        include StandardObject

        ORTHOGRAPHIC          = :O
        PERSPECTIVE           = :P

        module ClippingStyles
            EXPLICIT_NEARFAR    = :XNF
            AUTOMATIC_NEARFAR   = :ANF
        end

        module Scaling
            WIDTH               = :W
            HEIGHT              = :H
            MINIMUM             = :Min
            MAXIMUM             = :Max
            ABSOLUTE            = :Absolute
        end

        field   :Subtype,       :Type => Name, :Default => ORTHOGRAPHIC
        field   :CS,            :Type => Name, :Default => ClippingStyles::AUTOMATIC_NEARFAR
        field   :F,             :Type => Number
        field   :N,             :Type => Number
        field   :FOV,           :Type => Number
        field   :PS,            :Type => [ Number, Name ], :Default => Scaling::WIDTH
        field   :OS,            :Type => Number, :Default => 1
        field   :OB,            :Type => Name, :Version => "1.7", :Default => Scaling::ABSOLUTE
    end

    class Background3D < Dictionary
        include StandardObject

        field   :Type,          :Type => Name, :Default => :"3DBG"
        field   :Subtype,       :Type => Name, :Default => :SC
        field   :CS,            :Type => [ Name, Array ], :Default => Graphics::Color::Space::DEVICE_RGB
        field   :C,             :Type => Object, :Default => [ 1, 1, 1 ]
        field   :EA,            :Type => Boolean, :Default => false
    end

    class RenderMode3D < Dictionary
        include StandardObject

        module Modes
            SOLID                           = :Solid
            SOLID_WIREFRAME                 = :SolidWireFrame
            TRANSPARENT                     = :Transparent
            TRANSPARENT_WIREFRAME           = :TransparentWireFrame
            BOUNDINGBOX                     = :BoundingBox
            TRANSPARENT_BOUNDINGBOX         = :TransparentBoundingBox
            TRANSPARENT_BOUNDINGBOX_OUTLINE = :TransparentBoundingBoxOutline
            WIREFRAME                       = :WireFrame
            SHADED_WIREFRAME                = :ShadedWireFrame
            HIDDEN_WIREFRAME                = :HiddenWireFrame
            VERTICES                        = :Vertices
            SHADED_VERTICES                 = :ShadedVertices
            ILLUSTRATION                    = :Illustration
            SOLID_OUTLINE                   = :SolidOutline
            SHADED_ILLUSTRATION             = :ShadedIllustration
        end

        field   :Type,          :Type => Name, :Default => :"3DRenderMode"
        field   :Subtype,       :Type => Name, :Required => true, :Version => "1.7"
        field   :AC,            :Type => Array, :Default => [ Graphics::Color::Space::DEVICE_RGB, 0, 0, 0]
        field   :BG,            :Type => [ Name, Array ], :Default => :BG
        field   :O,             :Type => Number, :Default => 0.5
        field   :CV,            :Type => Number, :Default => 45
    end

    class LightingScheme3D < Dictionary
        include StandardObject

        module Styles
            ARTWORK                         = :Artwork
            NONE                            = :None
            WHITE                           = :White
            DAY                             = :Day
            NIGHT                           = :Night
            HARD                            = :Hard
            PRIMARY                         = :Primary
            BLUE                            = :Blue
            RED                             = :Red
            CUBE                            = :Cube
            CAD                             = :CAD
            HEADLAMP                        = :HeadLamp
        end

        field   :Type,          :Type => Name, :Default => :"3DLightingScheme"
        field   :Subtype,       :Type => Name, :Version => "1.7", :Required => true
    end

    class CrossSection3D < Dictionary
        include StandardObject

        field   :Type,          :Type => Name, :Default => :"3DCrossSection"
        field   :C,             :Type => Array, :Default => [ 0, 0, 0 ]
        field   :O,             :Type => Array, :Version => "1.7", :Default => [ Null.new, 0, 0 ], :Required => true
        field   :PO,            :Type => Number, :Default => 0.5
        field   :PC,            :Type => Array, :Default => [ Graphics::Color::Space::DEVICE_RGB, 1, 1, 1 ]
        field   :IV,            :Type => Boolean, :Default => false
        field   :IC,            :Type => Array, :Default => [ Graphics::Color::Space::DEVICE_RGB, 0, 1 ,0]
    end

    class Node3D < Dictionary
        include StandardObject

        field   :Type,          :Type => Name, :Default => :"3DNode"
        field   :N,             :Type => String, :Version => "1.7", :Required => true
        field   :O,             :Type => Number
        field   :V,             :Type => Boolean
        field   :M,             :Type => Array
    end

    class Measurement3D < Dictionary
        include StandardObject

        field   :Type,          :Type => Name, :Default => :"3DMeasure"
        field   :Subtype,       :Type => Name, :Required => true
        field   :TRL,           :Type => String
    end

    class LinearDimensionMeasurement3D < Measurement3D
        field   :Subtype,       :Type => Name, :Default => :L3D, :Required => true
        field   :AP,            :Type => Array.of(Number, length: 3), :Required => true
        field   :A1,            :Type => Array.of(Number, length: 3), :Required => true
        field   :N1,            :Type => String
        field   :A2,            :Type => Array.of(Number, length: 3), :Required => true
        field   :N2,            :Type => String
        field   :TP,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TY,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TS,            :Type => Number
        field   :C,             :Type => Array.of(Number, length: 3)
        field   :V,             :Type => Number, :Required => true
        field   :U,             :Type => String, :Required => true
        field   :P,             :Type => Integer, :Default => 3
        field   :UT,            :Type => String
        field   :S,             :Type => Annotation::Projection
    end

    class PerpendicularDimensionMeasurement3D < Measurement3D
        field   :Subtype,       :Type => Name, :Default => :PD3, :Required => true
        field   :AP,            :Type => Array.of(Number, length: 3), :Required => true
        field   :A1,            :Type => Array.of(Number, length: 3), :Required => true
        field   :N1,            :Type => String
        field   :A2,            :Type => Array.of(Number, length: 3), :Required => true
        field   :N2,            :Type => String
        field   :D1,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TP,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TY,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TS,            :Type => Number
        field   :C,             :Type => Array.of(Number, length: 3)
        field   :V,             :Type => Number, :Required => true
        field   :U,             :Type => String, :Required => true
        field   :P,             :Type => Integer, :Default => 3
        field   :UT,            :Type => String
        field   :S,             :Type => Annotation::Projection
    end

    class AngularDimensionMeasurement3D < Measurement3D
        field   :Subtype,       :Type => Name, :Default => :AD3, :Required => true
        field   :AP,            :Type => Array.of(Number, length: 3), :Required => true
        field   :A1,            :Type => Array.of(Number, length: 3), :Required => true
        field   :D1,            :Type => Array.of(Number, length: 3), :Required => true
        field   :N1,            :Type => String
        field   :A2,            :Type => Array.of(Number, length: 3), :Required => true
        field   :D2,            :Type => Array.of(Number, length: 3), :Required => true
        field   :N2,            :Type => String
        field   :TP,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TX,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TY,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TS,            :Type => Number
        field   :C,             :Type => Array.of(Number, length: 3)
        field   :V,             :Type => Number, :Required => true
        field   :P,             :Type => Integer, :Default => 3
        field   :UT,            :Type => String
        field   :DR,            :Type => Boolean, :Default => true
        field   :S,             :Type => Annotation::Projection
    end

    class RadialMeasurement3D < Measurement3D
        field   :Subtype,       :Type => Name, :Default => :RD3, :Required => true
        field   :AP,            :Type => Array.of(Number, length: 3), :Required => true
        field   :A1,            :Type => Array.of(Number, length: 3), :Required => true
        field   :A2,            :Type => Array.of(Number, length: 3), :Required => true
        field   :N2,            :Type => String
        field   :A3,            :Type => Array.of(Number, length: 3), :Required => true
        field   :A4,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TP,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TX,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TY,            :Type => Array.of(Number, length: 3), :Required => true
        field   :EL,            :Type => Number, :Default => 60 
        field   :TS,            :Type => Number
        field   :C,             :Type => Array.of(Number, length: 3)
        field   :V,             :Type => Number, :Required => true
        field   :U,             :Type => String, :Required => true
        field   :P,             :Type => Integer, :Default => 3
        field   :UT,            :Type => String
        field   :SC,            :Type => Boolean, :Default => false
        field   :R,             :Type => Boolean, :Default => true
        field   :S,             :Type => Annotation::Projection
    end

    class CommentNote3D < Measurement3D
        field   :Subtype,       :Type => Name, :Default => :"3DC", :Required => true
        field   :A1,            :Type => Array.of(Number, length: 3), :Required => true
        field   :N1,            :Type => String
        field   :TP,            :Type => Array.of(Number, length: 3), :Required => true
        field   :TB,            :Type => Array.of(Integer, length: 2)
        field   :TS,            :Type => Number
        field   :C,             :Type => Array.of(Number, length: 3)
        field   :UT,            :Type => String
        field   :S,             :Type => Annotation::Projection
    end

    class View3D < Dictionary
        include StandardObject

        field   :Type,          :Type => Name, :Default => :"3DView"
        field   :XN,            :Type => String, :Required => true
        field   :IN,            :Type => String
        field   :MS,            :Type => Name
        field   :C2W,           :Type => Array
        field   :U3DPath,       :Type => [ String, Array.of(String) ]
        field   :CO,            :Type => Number
        field   :P,             :Type => Projection3D
        field   :O,             :Type => Graphics::FormXObject
        field   :BG,            :Type => Background3D
        field   :RM,            :Type => RenderMode3D, :Version => "1.7"
        field   :LS,            :Type => LightingScheme3D, :Version => "1.7"
        field   :SA,            :Type => Array.of(CrossSection3D), :Version => "1.7"
        field   :NA,            :Type => Array.of(Node3D), :Version => "1.7"
        field   :NR,            :Type => Boolean, :Version => "1.7", :Default => false
    end

    class AnimationStyle3D < Dictionary
        include StandardObject

        module Styles
            NONE                = :None
            LINEAR              = :Linear
            OSCILLATING         = :Oscillating
        end

        field   :Type,          :Type => Name, :Default => :"3DAnimationStyle"
        field   :Subtype,       :Type => Name, :Default => Styles::NONE
        field   :PC,            :Type => Integer, :Default => 0
        field   :TM,            :Type => Number, :Default => 1
    end

    class U3DStream < Stream
        include StandardObject

        module Type
            U3D = :U3D
            PRC = :PRC
        end

        field   :Type,          :Type => Name, :Default => :"3D"
        field   :Subtype,       :Type => Name, :Default => Type::U3D, :Required => true, :Version => "1.7", :ExtensionLevel => 3
        field   :VA,            :Type => Array.of(View3D)
        field   :DV,            :Type => Object
        field   :Resources,     :Type => Dictionary
        field   :OnInstantiate, :Type => Stream
        field   :AN,            :Type => AnimationStyle3D

        def onInstantiate(action)
            self[:OnInstantiate] = action
        end
    end

    class Reference3D < Dictionary
        include StandardObject

        field   :Type,          :Type => Name, :Default => :"3DRef"
        field   :"3DD",         :Type => U3DStream
    end

    class Units3D < Dictionary
        include StandardObject

        field   :TSm,           :Type => Number, :Default => 1.0
        field   :TSn,           :Type => Number, :Default => 1.0
        field   :TU,            :Type => String
        field   :USm,           :Type => Number, :Default => 1.0
        field   :USn,           :Type => Number, :Default => 1.0
        field   :UU,            :Type => String
        field   :DSm,           :Type => Number, :Default => 1.0
        field   :DSn,           :Type => Number, :Default => 1.0
        field   :DU,            :Type => String
    end

    class Annotation

        #
        # 3D Artwork annotation.
        #
        class Artwork3D < Annotation

            class Activation < Dictionary
                include StandardObject

                module Events
                    PAGE_OPEN       = :PO
                    PAGE_CLOSE      = :PC
                    PAGE_VISIBLE    = :PV
                    PAGE_INVISIBLE  = :PI
                    USER_ACTIVATE   = :XA
                    USER_DEACTIVATE = :XD
                end

                module State
                    UNINSTANCIATED  = :U
                    INSTANCIATED    = :I
                    LIVE            = :L
                end
                
                module Style
                    EMBEDDED        = :Embedded
                    WINDOWED        = :Windowed
                end

                field   :A,             :Type => Name, :Default => Events::USER_ACTIVATE
                field   :AIS,           :Type => Name, :Default => State::LIVE
                field   :D,             :Type => Name, :Default => Events::PAGE_INVISIBLE
                field   :DIS,           :Type => Name, :Default => State::UNINSTANCIATED
                field   :TB,            :Type => Boolean, :Version => "1.7", :Default => true
                field   :NP,            :Type => Boolean, :Version => "1.7", :Default => false
                field   :Style,         :Type => Name, :Version => "1.7", :ExtensionLevel => 3, :Default => Style::EMBEDDED
                field   :Window,        :Type => RichMedia::Window, :Version => "1.7", :ExtensionLevel => 3
                field   :Transparent,   :Type => Boolean, :Version => "1.7", :ExtensionLevel => 3, :Default => false
            end

            field   :Subtype,     :Type => Name, :Default => :"3D", :Version => "1.6", :Required => true
            field   :"3DD",       :Type => [ Reference3D, U3DStream ], :Required => true
            field   :"3DV",       :Type => Object
            field   :"3DA",       :Type => Activation
            field   :"3DI",       :Type => Boolean, :Default => true
            field   :"3DB",       :Type => Rectangle
            field   :"3DU",       :Type => Units3D, :Version => "1.7", :ExtensionLevel => 3
        end
    end

end
