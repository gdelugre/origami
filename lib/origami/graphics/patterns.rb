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

    module Graphics

        module Pattern
            module Type
                TILING  = 1
                SHADING = 2
            end

            def self.included(receiver)
                receiver.field  :Type,          :Type => Name, :Default => :Pattern
                receiver.field  :PatternType,   :Type => Integer, :Required => true
            end

            class Tiling < ContentStream
                include Pattern
                include ResourcesHolder

                module PaintType
                    COLOURED    = 1
                    UNCOLOURED  = 2
                end

                module Type
                    CONSTANT_SPACING                    = 1
                    NO_DISTORTION                       = 2
                    CONSTANT_SPACING_AND_FASTER_TILING  = 3
                end

                field   :PatternType,           :Type => Integer, :Default => Pattern::Type::TILING, :Required => true
                field   :PaintType,             :Type => Integer, :Required => true
                field   :TilingType,            :Type => Integer, :Required => true
                field   :BBox,                  :Type => Rectangle, :Required => true
                field   :XStep,                 :Type => Number, :Required => true
                field   :YStep,                 :Type => Number, :Required => true
                field   :Resources,             :Type => Resources, :Required => true
                field   :Matrix,                :Type => Array.of(Number, length: 6), :Default => [ 1, 0, 0, 1, 0, 0 ]
            end

            class Shading < Dictionary
                include StandardObject
                include Pattern

                module Type
                    FUNCTION_BASED              = 1
                    AXIAL                       = 2
                    RADIAL                      = 3
                    FREEFORM_TRIANGLE_MESH      = 4
                    LATTICEFORM_TRIANGLE_MESH   = 5
                    COONS_PATCH_MESH            = 6
                    TENSORPRODUCT_PATCH_MESH    = 7
                end

                field   :PatternType,           :Type => Integer, :Default => Pattern::Type::SHADING, :Required => true
                field   :Shading,               :Type => [ Dictionary, Stream ], :Required => true
                field   :Matrix,                :Type => Array.of(Number, length: 6), :Default => [ 1, 0, 0, 1, 0, 0 ]
                field   :ExtGState,             :Type => ExtGState

                # Fields common to all shading objects.
                module ShadingObject
                    def self.included(receiver)
                        receiver.field   :ShadingType,         :Type => Integer, :Required => true
                        receiver.field   :ColorSpace,          :Type => [ Name, Array ], :Required => true
                        receiver.field   :Background,          :Type => Array
                        receiver.field   :BBox,                :Type => Rectangle
                        receiver.field   :AntiAlias,           :Type => Boolean, :Default => false
                    end
                end

                # Fields common to all Mesh shadings.
                module Mesh
                    def self.included(receiver)
                        receiver.field   :BitsPerCoordinate,   :Type => Integer, :Required => true
                        receiver.field   :BitsPerComponent,    :Type => Integer, :Required => true
                        receiver.field   :Decode,              :Type => Array.of(Number), :Required => true
                        receiver.field   :Function,            :Type => [ Dictionary, Stream ]
                    end
                end

                class FunctionBased < Dictionary
                    include StandardObject
                    include ShadingObject

                    field   :ShadingType,         :Type => Integer, :Default => Shading::Type::FUNCTION_BASED, :Required => true
                    field   :Domain,              :Type => Array.of(Number, length: 4), :Default => [ 0.0, 1.0, 0.0, 1.0 ]
                    field   :Matrix,              :Type => Array.of(Number, length: 6), :Default => [ 1, 0, 0, 1, 0, 0 ]
                    field   :Function,            :Type => [ Dictionary, Stream ], :Required => true
                end

                class Axial < Dictionary
                    include StandardObject
                    include ShadingObject

                    field   :ShadingType,         :Type => Integer, :Default => Shading::Type::AXIAL, :Required => true
                    field   :Coords,              :Type => Array.of(Number, length: 4), :Required => true
                    field   :Domain,              :Type => Array.of(Number, length: 2), :Default => [ 0.0, 1.0 ]
                    field   :Function,            :Type => [ Dictionary, Stream ], :Required => true
                    field   :Extend,              :Type => Array.of(Boolean, length: 2), :Default => [ false, false ]
                end

                class Radial < Dictionary
                    include StandardObject
                    include ShadingObject

                    field   :ShadingType,         :Type => Integer, :Default => Shading::Type::RADIAL, :Required => true
                    field   :Coords,              :Type => Array.of(Number, length: 6), :Required => true
                    field   :Domain,              :Type => Array.of(Number, length: 2), :Default => [ 0.0, 1.0 ]
                    field   :Function,            :Type => [ Dictionary, Stream ], :Required => true
                    field   :Extend,              :Type => Array.of(Boolean, length: 2), :Default => [ false, false ]
                end

                class FreeFormTriangleMesh < Stream
                    include ShadingObject
                    include Mesh

                    field   :ShadingType,         :Type => Integer, :Default => Shading::Type::FREEFORM_TRIANGLE_MESH, :Required => true
                    field   :BitsPerFlag,         :Type => Integer, :Required => true
                end

                class LatticeFormTriangleMesh < Stream
                    include ShadingObject
                    include Mesh

                    field   :ShadingType,         :Type => Integer, :Default => Shading::Type::LATTICEFORM_TRIANGLE_MESH, :Required => true
                    field   :VerticesPerRow,      :Type => Integer, :Required => true
                end

                class CoonsPathMesh < Stream
                    include ShadingObject
                    include Mesh

                    field   :ShadingType,         :Type => Integer, :Default => Shading::Type::COONS_PATCH_MESH, :Required => true
                    field   :BitsPerFlag,         :Type => Integer, :Required => true
                end

                class TensorProductPatchMesh < Stream
                    include ShadingObject

                    field   :ShadingType,         :Type => Integer, :Default => Shading::Type::TENSORPRODUCT_PATCH_MESH, :Required => true
                    field   :BitsPerFlag,         :Type => Integer, :Required => true
                end
            end

        end
    end

    class PDF::Instruction
        insn 'sh',  Name do |canvas, shading|
            canvas.paint_shading(shading)
        end
    end

end
