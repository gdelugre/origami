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
        # Sets PDF extension level and version. Only supported values are "1.7" and 3.
        #
        def set_extension_level(version, level)
            exts = (self.Catalog.Extensions ||= Extensions.new)

            exts[:ADBE] = DeveloperExtension.new
            exts[:ADBE].BaseVersion = Name.new(version)
            exts[:ADBE].ExtensionLevel = level

            self
        end

        #
        # Returns the current Catalog Dictionary.
        #
        def Catalog
            cat = trailer_key(:Root)
            raise InvalidPDFError, "Broken catalog" unless cat.is_a?(Catalog)

            cat
        end

        #
        # Sets the current Catalog Dictionary.
        #
        def Catalog=(cat)
            raise TypeError, "Must be a Catalog object" unless cat.is_a?(Catalog)

            delete_object(@revisions.last.trailer[:Root]) if @revisions.last.trailer[:Root]

            @revisions.last.trailer.Root = self << cat
        end

        #
        # Sets an action to run on document opening.
        # _action_:: An Action Object.
        #
        def onDocumentOpen(action)
            self.Catalog.OpenAction = action

            self
        end

        #
        # Sets an action to run on document closing.
        # _action_:: A JavaScript Action Object.
        #
        def onDocumentClose(action)
            self.Catalog.AA ||= CatalogAdditionalActions.new
            self.Catalog.AA.WC = action

            self
        end

        #
        # Sets an action to run on document printing.
        # _action_:: A JavaScript Action Object.
        #
        def onDocumentPrint(action)
            self.Catalog.AA ||= CatalogAdditionalActions.new
            self.Catalog.AA.WP = action

            self
        end

        #
        # Registers an object into a specific Names root dictionary.
        # _root_:: The root dictionary (see Names::Root)
        # _name_:: The value name.
        # _value_:: The value to associate with this name.
        #
        def register(root, name, value)
            self.Catalog.Names ||= Names.new

            value.set_indirect(true) unless value.is_a?(Reference)

            namesroot = self.Catalog.Names[root]
            if namesroot.nil?
                names = NameTreeNode.new(:Names => []).set_indirect(true)
                self.Catalog.Names[root] = names
                names.Names << name << value
            else
                namesroot.solve[:Names] << name << value
            end
        end

        #
        # Retrieve the corresponding value associated with _name_ in
        # the specified _root_ name directory, or nil if the value does
        # not exist.
        #
        def resolve_name(root, name)
            namesroot = get_names_root(root)
            return nil if namesroot.nil?

            resolve_name_from_node(namesroot, name)
        end

        #
        # Returns a Hash of all names under the specified _root_ name directory.
        #
        def names(root)
            self.each_name(root).to_h
        end

        #
        # Returns an Enumerator of all names under the specified _root_ name directory.
        #
        def each_name(root, &block)
            return enum_for(__method__, root) unless block_given?

            names_root = get_names_root(root)
            return if names_root.nil?

            names_from_node(names_root, &block)
            self
        end

        private

        def names_from_node(node, browsed_nodes: [], &block) #:nodoc:
            return if browsed_nodes.any?{|browsed| browsed.equal?(node)}
            raise InvalidNameTreeError, "node is not a dictionary" unless node.is_a?(Dictionary)

            browsed_nodes.push(node)

            if node.has_key?(:Names) # leaf node
                names = node.Names
                raise InvalidNameTreeError, "Names must be an Array" unless names.is_a?(Array)
                raise InvalidNameTreeError, "Odd number of elements" if names.length.odd?

                for i in 0...names.length/2
                    yield(names[i * 2].solve, names[i * 2 + 1].solve)
                end

            elsif node.has_key?(:Kids) # intermediate node
                node.Kids.each do |kid|
                    names_from_node(kid.solve, browsed_nodes: browsed_nodes, &block)
                end
            end
        end

        def resolve_name_from_node(node, name, browsed_nodes: []) #:nodoc:
            return if browsed_nodes.any?{|browsed| browsed.equal?(node)}
            raise InvalidNameTreeError, "node is not a Dictionary" unless node.is_a?(Dictionary)

            browsed_nodes.push(node)

            if node.has_key?(:Names) # leaf node
                limits = node.Limits
                names = node.Names

                raise InvalidNameTreeError, "Names must be an Array" unless names.is_a?(Array)
                raise InvalidNameTreeError, "Odd number of elements" if names.length.odd?

                if limits.is_a?(Array)
                    raise InvalidNameTreeError, "Invalid Limits array" unless limits.length == 2

                    min, max = limits[0].value, limits[1].value
                    if name.to_str >= min and name.to_str <= max
                        names = Hash[*names]
                        target = names[name]
                        return target && target.solve
                    end
                else
                    names = Hash[*names]
                    target = names[name]
                    return target && target.solve
                end

            elsif node.has_key?(:Kids) # intermediate node
                raise InvalidNameTreeError, "Kids must be an Array" unless node.Kids.is_a?(Array)

                node.Kids.each do |kid|
                    kid = kid.solve
                    limits = kid.Limits
                    unless limits.is_a?(Array) and limits.length == 2
                        raise InvalidNameTreeError, "Invalid Limits array"
                    end

                    min, max = limits[0].value, limits[1].value

                    if name.to_str >= min and name.to_str <= max
                        return resolve_name_from_node(kid, name, browsed_nodes: browsed_nodes)
                    end
                end
            end
        end

        def get_names_root(root) #:nodoc:
            namedirs = self.Catalog.Names
            return nil if namedirs.nil? or namedirs[root].nil?

            namedirs[root].solve
        end
    end

    module PageLayout #:nodoc:
        SINGLE            = :SinglePage
        ONE_COLUMN        = :OneColumn
        TWO_COLUMN_LEFT   = :TwoColumnLeft
        TWO_COLUMN_RIGHT  = :TwoColumnRight
        TWO_PAGE_LEFT     = :TwoPageLeft
        TWO_PAGE_RIGHT    = :TwoPageRight
    end

    module PageMode #:nodoc:
        NONE        = :UseNone
        OUTLINES    = :UseOutlines
        THUMBS      = :UseThumbs
        FULLSCREEN  = :FullScreen
        OPTIONAL_CONTENT = :UseOC
        ATTACHMENTS = :UseAttachments
    end

    #
    # Class representing additional actions which can be associated with a Catalog.
    #
    class CatalogAdditionalActions < Dictionary
        include StandardObject

        field   :WC,                  :Type => Action, :Version => "1.4"
        field   :WS,                  :Type => Action, :Version => "1.4"
        field   :DS,                  :Type => Action, :Version => "1.4"
        field   :WP,                  :Type => Action, :Version => "1.4"
        field   :DP,                  :Type => Action, :Version => "1.4"
    end

    #
    # Class representing the Names Dictionary of a PDF file.
    #
    class Names < Dictionary
        include StandardObject

        #
        # Defines constants for Names tree root entries.
        #
        DESTINATIONS            = :Dests
        AP                      = :AP
        JAVASCRIPT              = :JavaScript
        PAGES                   = :Pages
        TEMPLATES               = :Templates
        IDS                     = :IDS
        URLS                    = :URLS
        EMBEDDED_FILES          = :EmbeddedFiles
        ALTERNATE_PRESENTATIONS = :AlternatePresentations
        RENDITIONS              = :Renditions
        XFA_RESOURCES           = :XFAResources

        field   DESTINATIONS, :Type => NameTreeNode.of([DestinationDictionary, Destination]), :Version => "1.2"
        field   AP,           :Type => NameTreeNode.of(Annotation::AppearanceStream), :Version => "1.3"
        field   JAVASCRIPT,   :Type => NameTreeNode.of(Action::JavaScript), :Version => "1.3"
        field   PAGES,        :Type => NameTreeNode.of(Page), :Version => "1.3"
        field   TEMPLATES,    :Type => NameTreeNode.of(Page), :Version => "1.3"
        field   IDS,          :Type => NameTreeNode.of(WebCapture::ContentSet), :Version => "1.3"
        field   URLS,         :Type => NameTreeNode.of(WebCapture::ContentSet), :Version => "1.3"
        field   EMBEDDED_FILES,  :Type => NameTreeNode.of(FileSpec), :Version => "1.4"
        field   ALTERNATE_PRESENTATIONS, :Type => NameTreeNode, :Version => "1.4"
        field   RENDITIONS,   :Type => NameTreeNode, :Version => "1.5"
        field   XFA_RESOURCES, :Type => NameTreeNode.of(XFAStream), :Version => "1.7", :ExtensionLevel => 3
    end

    #
    # Class representing a leaf in a Name tree.
    #
    class NameLeaf < Array.of(String, Object)

        #
        # Creates a new leaf in a Name tree.
        # _hash_:: A hash of couples, associating a Name with an Reference.
        #
        def initialize(hash = {})
            super(hash.flat_map {|name, obj| [name.dup, obj]})
        end
    end

    #
    # Class representing the ViewerPreferences Dictionary of a PDF.
    # This dictionary modifies the way the UI looks when the file is opened in a viewer.
    #
    class ViewerPreferences < Dictionary
        include StandardObject

        # Valid values for the Enforce field.
        module Enforce
            PRINT_SCALING = :PrintScaling
        end

        field   :HideToolbar,             :Type => Boolean, :Default => false
        field   :HideMenubar,             :Type => Boolean, :Default => false
        field   :HideWindowUI,            :Type => Boolean, :Default => false
        field   :FitWindow,               :Type => Boolean, :Default => false
        field   :CenterWindow,            :Type => Boolean, :Default => false
        field   :DisplayDocTitle,         :Type => Boolean, :Default => false, :Version => "1.4"
        field   :NonFullScreenPageMode,   :Type => Name, :Default => :UseNone
        field   :Direction,               :Type => Name, :Default => :L2R
        field   :ViewArea,                :Type => Name, :Default => :CropBox, :Version => "1.4"
        field   :ViewClip,                :Type => Name, :Default => :CropBox, :Version => "1.4"
        field   :PrintArea,               :Type => Name, :Default => :CropBox, :Version => "1.4"
        field   :PrintClip,               :Type => Name, :Default => :CropBox, :Version => "1.4"
        field   :PrintScaling,            :Type => Name, :Default => :AppDefault, :Version => "1.6"
        field   :Duplex,                  :Type => Name, :Default => :Simplex, :Version => "1.7"
        field   :PickTrayByPDFSize,       :Type => Boolean, :Version => "1.7"
        field   :PrintPageRange,          :Type => Array.of(Integer), :Version => "1.7"
        field   :NumCopies,               :Type => Integer, :Version => "1.7"
        field   :Enforce,                 :Type => Array.of(Name), :Version => "1.7", :ExtensionLevel => 3
    end

    class Requirement < Dictionary
        include StandardObject

        class Handler < Dictionary
            include StandardObject

            module Type
                JS    = :JS
                NOOP  = :NoOp
            end

            field   :Type,                :Type => Name, :Default => :ReqHandler
            field   :S,                   :Type => Name, :Default => Type::NOOP, :Required => true
            field   :Script,              :Type => String
        end

        field   :Type,                    :Type => Name, :Default => :Requirement
        field   :S,                       :Type => Name, :Default => :EnableJavaScripts, :Version => "1.7", :Required => true
        field   :RH,                      :Type => Array.of(Handler)
    end

    #
    # Class representing a developer extension.
    #
    class DeveloperExtension < Dictionary
        include StandardObject

        field   :Type,                    :Type => Name, :Default => :DeveloperExtensions
        field   :BaseVersion,             :Type => Name, :Required => true
        field   :ExtensionLevel,          :Type => Integer, :Required => true
    end

    #
    # Class representing an extension Dictionary.
    #
    class Extensions < Dictionary
        include StandardObject

        field   :Type,                    :Type => Name, :Default => :Extensions
        field   :ADBE,                    :Type => DeveloperExtension
    end

    #
    # Class representing the Catalog Dictionary of a PDF file.
    #
    class Catalog < Dictionary
        include StandardObject

        field   :Type,                :Type => Name, :Default => :Catalog, :Required => true
        field   :Version,             :Type => Name, :Version => "1.4"
        field   :Pages,               :Type => PageTreeNode, :Required => true
        field   :PageLabels,          :Type => NumberTreeNode.of(PageLabel), :Version => "1.3"
        field   :Names,               :Type => Names, :Version => "1.2"
        field   :Dests,               :Type => Dictionary, :Version => "1.1"
        field   :ViewerPreferences,   :Type => ViewerPreferences, :Version => "1.2"
        field   :PageLayout,          :Type => Name, :Default => PageLayout::SINGLE
        field   :PageMode,            :Type => Name, :Default => PageMode::NONE
        field   :Outlines,            :Type => Outline
        field   :Threads,             :Type => Array, :Version => "1.1"
        field   :OpenAction,          :Type => [ Array, Dictionary ], :Version => "1.1"
        field   :AA,                  :Type => CatalogAdditionalActions, :Version => "1.4"
        field   :URI,                 :Type => Dictionary, :Version => "1.1"
        field   :AcroForm,            :Type => InteractiveForm, :Version => "1.2"
        field   :Metadata,            :Type => MetadataStream, :Version => "1.4"
        field   :StructTreeRoot,      :Type => Dictionary, :Version => "1.3"
        field   :MarkInfo,            :Type => Dictionary, :Version => "1.4"
        field   :Lang,                :Type => String, :Version => "1.4"
        field   :SpiderInfo,          :Type => WebCapture::SpiderInfo, :Version => "1.3"
        field   :OutputIntents,       :Type => Array.of(OutputIntent), :Version => "1.4"
        field   :PieceInfo,           :Type => Dictionary, :Version => "1.4"
        field   :OCProperties,        :Type => OptionalContent::Properties, :Version => "1.5"
        field   :Perms,               :Type => Dictionary, :Version => "1.5"
        field   :Legal,               :Type => Dictionary, :Version => "1.5"
        field   :Requirements,        :Type => Array.of(Requirement), :Version => "1.7"
        field   :Collection,          :Type => Collection, :Version => "1.7"
        field   :NeedsRendering,      :Type => Boolean, :Version => "1.7", :Default => false
        field   :Extensions,          :Type => Extensions, :Version => "1.7", :ExtensionLevel => 3

        def initialize(hash = {}, parser = nil)
            set_indirect(true)

            super(hash, parser)
        end
    end

end
