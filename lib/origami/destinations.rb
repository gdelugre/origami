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
        # Lookup destination in the destination name directory.
        #
        def get_destination_by_name(name)
            resolve_name Names::DESTINATIONS, name
        end

        #
        # Calls block for each named destination.
        #
        def each_named_dest(&b)
            each_name(Names::DESTINATIONS, &b)
        end
    end

    #
    # A destination represents a specified location into the document.
    #
    class Destination < Origami::Array
        attr_reader :page, :top, :left, :right, :bottom, :zoom

        #
        # Class representing a Destination zooming on a part of a document.
        #
        class Zoom < Destination

            def initialize(array)
                super(array)

                @page, _, @left, @top, @zoom = array
            end

            #
            # Creates a new zoom Destination.
            # _page_:: The destination Page.
            # _left_, _top_:: Coords in the Page.
            # _zoom_:: Zoom factor.
            #
            def self.[](page, left: 0, top: 0, zoom: 0)
                self.new([page, :XYZ, left, top, zoom])
            end
        end

        def self.Zoom(page, left: 0, top: 0, zoom: 0)
            Zoom[page, left: left, top: top, zoom: zoom]
        end


        #
        # Class representing a Destination showing a Page globally.
        #
        class GlobalFit < Destination

            def initialize(array)
                super(array)

                @page, _ = array
            end

            #
            # Creates a new global fit Destination.
            # _page_:: The destination Page.
            #
            def self.[](page)
                self.new([page, :Fit])
            end
        end

        def self.GlobalFit(page)
            GlobalFit[page]
        end

        #
        # Class representing a Destination fitting a Page horizontally.
        #
        class HorizontalFit < Destination

            def initialize(array)
                super(array)

                @page, _, @top = array
            end

            #
            # Creates a new horizontal fit destination.
            # _page_:: The destination Page.
            # _top_:: The vertical coord in the Page.
            #
            def self.[](page, top: 0)
                self.new([page, :FitH, top])
            end
        end

        def self.HorizontalFit(page, top: 0)
            HorizontalFit[page, top: top]
        end

        #
        # Class representing a Destination fitting a Page vertically.
        # _page_:: The destination Page.
        # _left_:: The horizontal coord in the Page.
        #
        class VerticalFit < Destination

            def initialize(array)
                super(array)

                @page, _,  @left = array
            end

            def self.[](page, left: 0)
                self.new([page, :FitV, left])
            end
        end

        def self.VerticalFit(page, left: 0)
            VerticalFit[page, left: left]
        end

        #
        # Class representing a Destination fitting the view on a rectangle in a Page.
        #
        class RectangleFit < Destination

            def initialize(array)
                super(array)

                @page, _, @left, @bottom, @right, @top = array
            end

            #
            # Creates a new rectangle fit Destination.
            # _page_:: The destination Page.
            # _left_, _bottom_, _right_, _top_:: The rectangle to fit in.
            #
            def self.[](page, left: 0, bottom: 0, right: 0, top: 0)
                self.new([page, :FitR, left, bottom, right, top])
            end
        end

        def self.RectangleFit(page, left: 0, bottom: 0, right: 0, top: 0)
            RectangleFit[page, left: left, bottom: bottom, right: right, top: top]
        end

        #
        # Class representing a Destination fitting the bounding box of a Page.
        #
        class GlobalBoundingBoxFit < Destination

            def initialize(array)
                super(array)

                @page, _, = array
            end

            #
            # Creates a new bounding box fit Destination.
            # _page_:: The destination Page.
            #
            def self.[](page)
                self.new([page, :FitB])
            end
        end

        def self.GlobalBoundingBoxFit(page)
            GlobalBoundingBoxFit[page]
        end

        #
        # Class representing a Destination fitting horizontally the bouding box a Page.
        #
        class HorizontalBoudingBoxFit < Destination

            def initialize(array)
                super(array)

                @page, _, @top = array
            end

            #
            # Creates a new horizontal bounding box fit Destination.
            # _page_:: The destination Page.
            # _top_:: The vertical coord.
            #
            def self.[](page, top: 0)
                self.new([page, :FitBH, top])
            end
        end

        def self.HorizontalBoudingBoxFit(page, top: 0)
            HorizontalBoudingBoxFit[page, top: top]
        end

        #
        # Class representing a Destination fitting vertically the bounding box of a Page.
        #
        class VerticalBoundingBoxFit < Destination

            def initialize(array)
                super(array)

                @page, _, @left = array
            end

            #
            # Creates a new vertical bounding box fit Destination.
            # _page_:: The destination Page.
            # _left_:: The horizontal coord.
            #
            def self.[](page, left: 0)
                self.new([page, :FitBV, left])
            end
        end

        def self.VerticalBoundingBoxFit(page, left: 0)
            VerticalBoundingBoxFit[page, left: left]
        end
    end

    #
    # This kind of Dictionary is used in named destinations.
    #
    class DestinationDictionary < Dictionary
        include StandardObject

        field   :D,         :Type => Destination, :Required => true
    end

end
