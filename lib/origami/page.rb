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
        # Appends a page or list of pages to the end of the page tree.
        # _page_:: The page to append to the document. Creates a new Page if not specified.
        #
        # Pass the Page object if a block is present.
        #
        def append_page(page = Page.new)
            init_page_tree

            self.Catalog.Pages.append_page(page)
            yield(page) if block_given?

            self
        end

        #
        # Inserts a page at position _index_ into the document.
        # _index_:: Page index (starting from one).
        # _page_:: The page to insert into the document. Creates a new one if none given.
        #
        # Pass the Page object if a block is present.
        #
        def insert_page(index, page = Page.new)
            init_page_tree

            # Page from another document must be exported.
            page = page.export if page.document and page.document != self

            self.Catalog.Pages.insert_page(index, page)

            yield(page) if block_given?

            self
        end

        #
        # Returns an Enumerator of Page
        #
        def pages
            init_page_tree

            self.Catalog.Pages.pages
        end

        #
        # Iterate through each page, returns self.
        #
        def each_page(&b)
            init_page_tree

            self.Catalog.Pages.each_page(&b)
        end

        #
        # Get the n-th Page object.
        #
        def get_page(n)
            init_page_tree

            self.Catalog.Pages.get_page(n)
        end

        #
        # Lookup page in the page name directory.
        #
        def get_page_by_name(name)
            resolve_name Names::PAGES, name
        end

        #
        # Calls block for each named page.
        #
        def each_named_page(&b)
            each_name(Names::PAGES, &b)
        end

        private

        def init_page_tree #:nodoc:
            unless self.Catalog.key?(:Pages)
                self.Catalog.Pages = PageTreeNode.new
                return
            end

            unless self.Catalog.Pages.is_a?(PageTreeNode)
                raise InvalidPageTreeError, "Root page node is not a PageTreeNode"
            end
        end
    end

    module ResourcesHolder

        def add_extgstate(extgstate, name = nil)
            add_resource(Resources::EXTGSTATE, extgstate, name)
        end
        def add_colorspace(colorspace, name = nil)
            add_resource(Resources::COLORSPACE, colorspace, name)
        end

        def add_pattern(pattern, name = nil)
            add_resource(Resources::PATTERN, pattern, name)
        end

        def add_shading(shading, name = nil)
            add_resource(Resources::SHADING, shading, name)
        end

        def add_xobject(xobject, name = nil)
            add_resource(Resources::XOBJECT, xobject, name)
        end

        def add_font(font, name = nil)
            add_resource(Resources::FONT, font, name)
        end

        def add_properties(properties, name = nil)
            add_resource(Resources::PROPERTIES, properties, name)
        end

        #
        # Adds a resource of the specified _type_ in the current object.
        # If _name_ is not specified, a new name will be automatically generated.
        #
        def add_resource(type, rsrc, name = nil)
            if name.nil?
                rsrc_name = self.resources(type).key(rsrc)
                return rsrc_name if rsrc_name
            end

            name ||= new_id(type)
            target = self.is_a?(Resources) ? self : (self.Resources ||= Resources.new)

            rsrc_dict = (target[type] and target[type].solve) || (target[type] = Dictionary.new)
            rsrc_dict[name.to_sym] = rsrc

            name
        end

        #
        # Iterates over the resources by _type_.
        #
        def each_resource(type)
            target = self.is_a?(Resources) ? self : (self.Resources ||= Resources.new)

            rsrc = (target[type] and target[type].solve)

            return enum_for(__method__, type) { rsrc.is_a?(Dictionary) ? rsrc.length : 0 } unless block_given?
            return unless rsrc.is_a?(Dictionary)

            rsrc.each_pair do |name, obj|
                yield(name.value, obj.solve)
            end
        end

        def each_colorspace(&block); each_resource(Resources::COLORSPACE, &block) end
        def each_extgstate(&block); each_resource(Resources::EXTGSTATE, &block) end
        def each_pattern(&block); each_resource(Resources::PATTERN, &block) end
        def each_shading(&block); each_resource(Resources::SHADING, &block) end
        def each_xobject(&block); each_resource(Resources::XOBJECT, &block) end
        def each_font(&block); each_resource(Resources::FONT, &block) end
        def each_property(&block); each_resource(Resources::PROPERTIES, &block) end

        def extgstates; each_extgstate.to_h end
        def colorspaces; each_colorspace.to_h end
        def patterns; each_pattern.to_h end
        def shadings; each_shading.to_h end
        def xobjects; each_xobject.to_h end
        def fonts; each_font.to_h end
        def properties; each_property.to_h end

        #
        # Returns a Hash of all resources in the object or only the specified _type_.
        #
        def resources(type = nil)
            if type.nil?
                self.extgstates
                    .merge self.colorspaces
                    .merge self.patterns
                    .merge self.shadings
                    .merge self.xobjects
                    .merge self.fonts
                    .merge self.properties
            else
                self.each_resource(type).to_h
            end
        end

        private

        def new_id(type, prefix = nil) #:nodoc:
            prefix ||=
            {
                Resources::EXTGSTATE  => 'ExtG',
                Resources::COLORSPACE => 'CS',
                Resources::PATTERN    => 'P',
                Resources::SHADING    => 'Sh',
                Resources::XOBJECT    => 'Im',
                Resources::FONT       => 'F',
                Resources::PROPERTIES => 'Pr'
            }[type]

            rsrc = self.resources(type)
            n = '1'

            n.next! while rsrc.include?((prefix + n).to_sym)

            Name.new(prefix + n)
        end
    end

    #
    # Class representing a Resources Dictionary for a Page.
    #
    class Resources < Dictionary
        include StandardObject
        include ResourcesHolder

        EXTGSTATE     = :ExtGState
        COLORSPACE    = :ColorSpace
        PATTERN       = :Pattern
        SHADING       = :Shading
        XOBJECT       = :XObject
        FONT          = :Font
        PROPERTIES    = :Properties

        field   EXTGSTATE,    :Type => Dictionary
        field   COLORSPACE,   :Type => Dictionary
        field   PATTERN,      :Type => Dictionary
        field   SHADING,      :Type => Dictionary, :Version => "1.3"
        field   XOBJECT,      :Type => Dictionary
        field   FONT,         :Type => Dictionary
        field   :ProcSet,     :Type => Array.of(Name)
        field   PROPERTIES,   :Type => Dictionary, :Version => "1.2"

        def pre_build
            add_font(Font::Type1::Standard::Helvetica.new.pre_build) unless self.Font

            super
        end
    end

    class InvalidPageTreeError < Error #:nodoc:
    end

    #
    # Class representing a node in a Page tree.
    #
    class PageTreeNode < Dictionary
        include StandardObject

        field   :Type,          :Type => Name, :Default => :Pages, :Required => true
        field   :Parent,        :Type => PageTreeNode
        field   :Kids,          :Type => Array, :Default => [], :Required => true
        field   :Count,         :Type => Integer, :Default => 0, :Required => true

        def initialize(hash = {}, parser = nil)
            super

            set_default_values # Ensure that basic tree fields are present.
            set_indirect(true)
        end

        def pre_build #:nodoc:
            self.Count = self.pages.count

            super
        end

        #
        # Inserts a page into the node at a specified position (starting from 1).
        #
        def insert_page(n, page)
            raise IndexError, "Page numbers are referenced starting from 1" if n < 1

            kids = self.Kids
            unless kids.is_a?(Array)
                raise InvalidPageTreeError, "Kids must be an Array"
            end

            count = 0
            kids.each_with_index do |kid, index|
                node = kid.solve

                case node
                when Page
                    count = count + 1
                    if count == n
                        kids.insert(index, page)
                        page.Parent = self
                        self.Count += 1
                        return self
                    end

                when PageTreeNode
                    count = count + node.Count
                    if count >= n
                        node.insert_page(n - count + node.Count, page)
                        self.Count += 1
                        return self
                    end
                else
                    raise InvalidPageTreeError, "not a Page or PageTreeNode"
                end
            end

            raise IndexError, "Out of order page index" unless count + 1 == n

            self.append_page(page)
        end

        #
        # Returns an Array of Pages inheriting this tree node.
        #
        def pages
            self.each_page.to_a
        end

        #
        # Iterate through each page of that node.
        #
        def each_page(browsed_nodes: [], &block)
            return enum_for(__method__) { self.Count.to_i } unless block_given?

            if browsed_nodes.any?{|node| node.equal?(self)}
                raise InvalidPageTreeError, "Cyclic tree graph detected"
            end

            unless self.Kids.is_a?(Array)
                raise InvalidPageTreeError, "Kids must be an Array"
            end

            browsed_nodes.push(self)

            unless self.Count.nil?
                [ self.Count.value, self.Kids.length ].min.times do |n|
                    node = self.Kids[n].solve

                    case node
                    when PageTreeNode then node.each_page(browsed_nodes: browsed_nodes, &block)
                    when Page then yield(node)
                    else
                        raise InvalidPageTreeError, "not a Page or PageTreeNode"
                    end
                end
            end

            self
        end

        #
        # Get the n-th Page object in this node, starting from 1.
        #
        def get_page(n)
            raise IndexError, "Page numbers are referenced starting from 1" if n < 1
            raise IndexError, "Page not found" if n > self.Count.to_i

            self.each_page.lazy.drop(n - 1).first or raise IndexError, "Page not found"
        end

        #
        # Removes all pages in the node.
        #
        def clear_pages
            self.Count = 0
            self.Kids = []
        end

        #
        # Returns true unless the node is empty.
        #
        def pages?
            self.each_page.size > 0
        end

        #
        # Append a page at the end of this node.
        #
        def append_page(page)
            self.Kids ||= []
            self.Kids.push(page)
            self.Count += 1

            page.Parent = self
        end
    end

    class PageLabel < Dictionary
        include StandardObject

        module Style
            DECIMAL = :D
            UPPER_ROMAN = :R
            LOWER_ROMAN = :r
            UPPER_ALPHA = :A
            LOWER_ALPHA = :a
        end

        field   :Type,                  :Type => Name, :Default => :PageLabel
        field   :S,                     :Type => Name
        field   :P,                     :Type => String
        field   :St,                    :Type => Integer
    end

    # Forward declarations.
    class ContentStream < Stream; end
    class Annotation < Dictionary; end
    module Graphics; class ImageXObject < Stream; end end

    #
    # Class representing a Page in the PDF document.
    #
    class Page < Dictionary
        include StandardObject
        include ResourcesHolder

        class BoxStyle < Dictionary
            include StandardObject

            SOLID = :S
            DASH  = :D

            field   :C,                 :Type => Array.of(Number), :Default => [0.0, 0.0, 0.0]
            field   :W,                 :Type => Number, :Default => 1
            field   :S,                 :Type => Name, :Default => SOLID
            field   :D,                 :Type => Array.of(Integer)
        end
             
        #
        # Box color information dictionary associated to a Page.
        #
        class BoxColorInformation < Dictionary
            include StandardObject

            field   :CropBox,           :Type => BoxStyle
            field   :BleedBox,          :Type => BoxStyle
            field   :TrimBox,           :Type => BoxStyle
            field   :ArtBox,            :Type => BoxStyle
        end

        #
        # Class representing a navigation node associated to a Page.
        #
        class NavigationNode < Dictionary
            include StandardObject

            field   :Type,    :Type => Name, :Default => :NavNode
            field   :NA,      :Type => Dictionary # Next action
            field   :PA,      :Type => Dictionary # Prev action
            field   :Next,    :Type => NavigationNode 
            field   :Prev,    :Type => NavigationNode 
            field   :Dur,     :Type => Number
        end

        #
        # Class representing additional actions which can be associated to a Page.
        #
        class AdditionalActions < Dictionary
            include StandardObject

            field   :O,   :Type => Dictionary, :Version => "1.2" # Page Open
            field   :C,   :Type => Dictionary, :Version => "1.2" # Page Close
        end

        module Format
            A0 = Rectangle[width: 2384, height: 3370]
            A1 = Rectangle[width: 1684, height: 2384]
            A2 = Rectangle[width: 1191, height: 1684]
            A3 = Rectangle[width: 842, height: 1191]
            A4 = Rectangle[width: 595, height: 842]
            A5 = Rectangle[width: 420, height: 595]
            A6 = Rectangle[width: 298, height: 420]
            A7 = Rectangle[width: 210, height: 298]
            A8 = Rectangle[width: 147, height: 210]
            A9 = Rectangle[width: 105, height: 147]
            A10 = Rectangle[width: 74, height: 105]

            B0 = Rectangle[width: 2836, height: 4008]
            B1 = Rectangle[width: 2004, height: 2835]
            B2 = Rectangle[width: 1417, height: 2004]
            B3 = Rectangle[width: 1001, height: 1417]
            B4 = Rectangle[width: 709, height: 1001]
            B5 = Rectangle[width: 499, height: 709]
            B6 = Rectangle[width: 354, height: 499]
            B7 = Rectangle[width: 249, height: 354]
            B8 = Rectangle[width: 176, height: 249]
            B9 = Rectangle[width: 125, height: 176]
            B10 = Rectangle[width: 88, height: 125]
        end

        field   :Type,                  :Type => Name, :Default => :Page, :Required => true
        field   :Parent,                :Type => PageTreeNode, :Required => true
        field   :LastModified,          :Type => String, :Version => "1.3"
        field   :Resources,             :Type => Resources, :Required => true
        field   :MediaBox,              :Type => Rectangle, :Default => Format::A4, :Required => true
        field   :CropBox,               :Type => Rectangle
        field   :BleedBox,              :Type => Rectangle, :Version => "1.3"
        field   :TrimBox,               :Type => Rectangle, :Version => "1.3"
        field   :ArtBox,                :Type => Rectangle, :Version => "1.3"
        field   :BoxColorInfo,          :Type => BoxColorInformation, :Version => "1.4"
        field   :Contents,              :Type => [ ContentStream, Array.of(ContentStream) ]
        field   :Rotate,                :Type => Integer, :Default => 0
        field   :Group,                 :Type => Dictionary, :Version => "1.4"
        field   :Thumb,                 :Type => Graphics::ImageXObject
        field   :B,                     :Type => Array, :Version => "1.1"
        field   :Dur,                   :Type => Integer, :Version => "1.1"
        field   :Trans,                 :Type => Dictionary, :Version => "1.1"
        field   :Annots,                :Type => Array.of(Annotation)
        field   :AA,                    :Type => AdditionalActions, :Version => "1.2"
        field   :Metadata,              :Type => MetadataStream, :Version => "1.4"
        field   :PieceInfo,             :Type => Dictionary, :Version => "1.2"
        field   :StructParents,         :Type => Integer, :Version => "1.3"
        field   :ID,                    :Type => String
        field   :PZ,                    :Type => Number
        field   :SeparationInfo,        :Type => Dictionary, :Version => "1.3"
        field   :Tabs,                  :Type => Name, :Version => "1.5"
        field   :TemplateAssociated,    :Type => Name, :Version => "1.5"
        field   :PresSteps,             :Type => NavigationNode, :Version => "1.5"
        field   :UserUnit,              :Type => Number, :Default => 1.0, :Version => "1.6"
        field   :VP,                    :Type => Dictionary, :Version => "1.6"

        def initialize(hash = {}, parser = nil)
            super(hash, parser)

            set_indirect(true)
        end

        def pre_build
            self.Resources = Resources.new.pre_build unless self.has_key?(:Resources)

            super
        end

        #
        # Iterates over all the ContentStreams of the Page.
        #
        def each_content_stream
            contents = self.Contents

            return enum_for(__method__) do
                case contents
                when Array then contents.length
                when Stream then 1
                else
                    0
                end
            end unless block_given?

            case contents
            when Stream then yield(contents)
            when Array then contents.each { |stm| yield(stm.solve) }
            end
        end

        #
        # Returns an Array of ContentStreams for the Page.
        #
        def content_streams
            self.each_content_stream.to_a
        end

        #
        # Add an Annotation to the Page.
        #
        def add_annotation(*annotations)
            self.Annots ||= []

            annotations.each do |annot|
                annot.solve[:P] = self if self.indirect?
                self.Annots << annot
            end
        end

        #
        # Iterate through each Annotation of the Page.
        #
        def each_annotation
            annots = self.Annots

            return enum_for(__method__) { annots.is_a?(Array) ? annots.length : 0 } unless block_given?
            return unless annots.is_a?(Array)

            annots.each do |annot|
                yield(annot.solve)
            end
        end

        #
        # Returns the array of Annotation objects of the Page.
        #
        def annotations
            self.each_annotation.to_a
        end

        #
        # Embed a SWF Flash application in the page.
        #
        def add_flash_application(swfspec, params = {})
            options =
            {
                windowed: false,
                transparent: false,
                navigation_pane: false,
                toolbar: false,
                pass_context_click: false,
                activation: Annotation::RichMedia::Activation::PAGE_OPEN,
                deactivation: Annotation::RichMedia::Deactivation::PAGE_CLOSE,
                flash_vars: nil
            }
            options.update(params)

            annot = create_richmedia(:Flash, swfspec, options)
            add_annotation(annot)

            annot
        end

        #
        # Will execute an action when the page is opened.
        #
        def onOpen(action)
            self.AA ||= Page::AdditionalActions.new
            self.AA.O = action

            self
        end

        #
        # Will execute an action when the page is closed.
        #
        def onClose(action)
            self.AA ||= Page::AdditionalActions.new
            self.AA.C = action

            self
        end

        #
        # Will execute an action when navigating forward from this page.
        #
        def onNavigateForward(action) #:nodoc:
            self.PresSteps ||= NavigationNode.new
            self.PresSteps.NA = action

            self
        end

        #
        # Will execute an action when navigating backward from this page.
        #
        def onNavigateBackward(action) #:nodoc:
            self.PresSteps ||= NavigationNode.new
            self.PresSteps.PA = action

            self
        end

        private

        def create_richmedia(type, content, params) #:nodoc:
            content.set_indirect(true)
            richmedia = Annotation::RichMedia.new.set_indirect(true)

            rminstance = Annotation::RichMedia::Instance.new.set_indirect(true)
            rmparams = rminstance.Params = Annotation::RichMedia::Parameters.new
            rmparams.Binding = Annotation::RichMedia::Parameters::Binding::BACKGROUND
            rmparams.FlashVars = params[:flash_vars]
            rminstance.Asset = content

            rmconfig = Annotation::RichMedia::Configuration.new.set_indirect(true)
            rmconfig.Instances = [ rminstance ]
            rmconfig.Subtype = type

            rmcontent = richmedia.RichMediaContent = Annotation::RichMedia::Content.new.set_indirect(true)
            rmcontent.Assets = NameTreeNode.new
            rmcontent.Assets.Names = NameLeaf.new(content.F.value => content)

            rmcontent.Configurations = [ rmconfig ]

            rmsettings = richmedia.RichMediaSettings = Annotation::RichMedia::Settings.new
            rmactivation = rmsettings.Activation = Annotation::RichMedia::Activation.new
            rmactivation.Condition = params[:activation]
            rmactivation.Configuration = rmconfig
            rmactivation.Animation = Annotation::RichMedia::Animation.new(:PlayCount => -1, :Subtype => :Linear, :Speed => 1.0)
            rmpres = rmactivation.Presentation = Annotation::RichMedia::Presentation.new
            rmpres.Style = Annotation::RichMedia::Presentation::WINDOWED if params[:windowed]
            rmpres.Transparent = params[:transparent]
            rmpres.NavigationPane = params[:navigation_pane]
            rmpres.Toolbar = params[:toolbar]
            rmpres.PassContextClick = params[:pass_context_click]

            rmdeactivation = rmsettings.Deactivation = Annotation::RichMedia::Deactivation.new
            rmdeactivation.Condition = params[:deactivation]

            richmedia
        end
    end

end
