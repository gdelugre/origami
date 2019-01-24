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

require 'origami/object'
require 'origami/compound'
require 'origami/null'
require 'origami/name'
require 'origami/dictionary'
require 'origami/reference'
require 'origami/boolean'
require 'origami/numeric'
require 'origami/string'
require 'origami/array'
require 'origami/stream'
require 'origami/tree'
require 'origami/filters'
require 'origami/header'
require 'origami/metadata'
require 'origami/functions'
require 'origami/page'
require 'origami/font'
require 'origami/graphics'
require 'origami/optionalcontent'
require 'origami/destinations'
require 'origami/filespec'
require 'origami/xfa'
require 'origami/acroform'
require 'origami/annotations'
require 'origami/actions'
require 'origami/3d'
require 'origami/signature'
require 'origami/webcapture'
require 'origami/encryption'
require 'origami/linearization'
require 'origami/obfuscation'
require 'origami/javascript'
require 'origami/outline'
require 'origami/outputintents'
require 'origami/collections'
require 'origami/catalog'
require 'origami/xreftable'
require 'origami/trailer'

require 'origami/parsers/pdf/linear'
require 'origami/parsers/pdf/lazy'

module Origami

    class InvalidPDFError < Error #:nodoc:
    end

    #
    # Main class representing a PDF file and its inner contents.
    # A PDF file contains a set of Revision.
    #
    class PDF

        #
        # Class representing a particular revision in a PDF file.
        # Revision contains :
        # * A Body, which is a sequence of Object.
        # * A XRef::Section, holding XRef information about objects in body.
        # * A Trailer.
        #
        class Revision
            attr_accessor :pdf
            attr_accessor :body, :xreftable, :xrefstm
            attr_reader :trailer

            def initialize(doc)
                @document = doc
                @body = {}
                @xreftable = nil
                @xrefstm = nil
                @trailer = nil
            end

            def trailer=(trl)
                trl.document = @document

                @trailer = trl
            end

            def xreftable?
                not @xreftable.nil?
            end

            def xrefstm?
                not @xrefstm.nil?
            end

            def each_object(&b)
                @body.each_value(&b)
            end

            def objects
                @body.values
            end
        end

        #
        # Document header and revisions.
        #
        attr_accessor :header, :revisions

        class << self
            #
            # Reads and parses a PDF file from disk.
            #
            def read(path, options = {})
                path = File.expand_path(path) if path.is_a?(::String)
                lazy = options[:lazy]

                if lazy
                    parser_class = PDF::LazyParser
                else
                    parser_class = PDF::LinearParser
                end

                parser_class.new(options).parse(path)
            end

            #
            # Creates a new PDF and saves it.
            # If a block is passed, the PDF instance can be processed before saving.
            #
            def create(output, options = {})
                pdf = PDF.new
                yield(pdf) if block_given?
                pdf.save(output, options)
            end
            alias write create
        end

        #
        # Creates a new PDF instance.
        # _parser_:: The Parser object creating the document.
        #            If none is specified, some default structures are automatically created to get a minimal working document.
        #
        def initialize(parser = nil)
            @header = PDF::Header.new
            @revisions = []
            @parser = parser
            @loaded = false

            add_new_revision
            @revisions.first.trailer = Trailer.new

            init if parser.nil?
        end

        #
        # Original file name if parsed from disk, nil otherwise.
        #
        def original_filename
            @parser.target_filename if @parser
        end

        #
        # Original file size if parsed from a data stream, nil otherwise.
        #
        def original_filesize
            @parser.target_filesize if @parser
        end

        #
        # Original data parsed to create this document, nil if created from scratch.
        #
        def original_data
            @parser.target_data if @parser
        end

        #
        # Saves the current document.
        # _filename_:: The path where to save this PDF.
        #
        def save(path, params = {})
            options =
            {
                delinearize: true,
                recompile: true,
                decrypt: false
            }
            options.update(params)

            if self.frozen? # incompatible flags with frozen doc (signed)
                options[:recompile] =
                options[:rebuild_xrefs] =
                options[:noindent] =
                options[:obfuscate] = false
            end

            if path.respond_to?(:write)
                fd = path
            else
                path = File.expand_path(path)
                fd = File.open(path, 'w').binmode
                close = true
            end

            load_all_objects unless loaded?

            intents_as_pdfa1 if options[:intent] =~ /pdf[\/-]?A1?/i
            self.delinearize! if options[:delinearize] and self.linearized?
            compile(options) if options[:recompile]

            fd.write output(options)
            fd.close if close

            self
        end
        alias write save

        #
        # Saves the file up to given revision number.
        # This can be useful to visualize the modifications over different incremental updates.
        # _revision_:: The revision number to save.
        # _filename_:: The path where to save this PDF.
        #
        def save_upto(revision, filename)
            save(filename, up_to_revision: revision)
        end

        #
        # Returns an array of strings, names and streams matching the given pattern.
        # _streams_: Search into decoded stream data.
        # _object_streams_: Search into objects inside object streams.
        #
        def grep(pattern, streams: true, object_streams: true) #:nodoc:

            pattern = /#{Regexp.escape(pattern)}/i if pattern.is_a?(::String)
            raise TypeError, "Expected a String or Regexp" unless pattern.is_a?(Regexp)

            result = []

            self.indirect_objects.each do |object|
                result.concat search_object(object, pattern,
                                            streams: streams, object_streams: object_streams)
            end

            result
        end

        #
        # Returns an array of Objects whose name (in a Dictionary) is matching _pattern_.
        #
        def ls(pattern, follow_references: true)

            pattern = /#{Regexp.escape(pattern)}/i if pattern.is_a?(::String)
            raise TypeError, "Expected a String or Regexp" unless pattern.is_a?(Regexp)

            self.grep(pattern, streams: false, object_streams: true)
                .select {|object| object.is_a?(Name) and object.parent.is_a?(Dictionary) and object.parent.key?(object) }
                .collect {|object| result = object.parent[object]; follow_references ? result.solve : result }
        end

        #
        # Iterates over the objects of the document.
        # _compressed_: iterates over the objects inside object streams.
        # _recursive_: iterates recursively inside objects like arrays and dictionaries.
        #
        def each_object(compressed: false, recursive: false, &block)
            return enum_for(__method__, compressed: compressed,
                                        recursive: recursive
                           ) unless block_given?

            @revisions.each do |revision|
                revision.each_object do |object|
                    block.call(object)

                    walk_object(object, &block) if recursive

                    if object.is_a?(ObjectStream) and compressed
                        object.each do |child_obj|
                            block.call(child_obj)

                            walk_object(child_obj) if recursive
                        end
                    end
                end
            end
        end

        #
        # Return an array of indirect objects.
        #
        def indirect_objects
            @revisions.inject([]) do |set, rev| set.concat(rev.objects) end
        end
        alias root_objects indirect_objects

        #
        # Adds a new object to the PDF file.
        # If this object has no version number, then a new one will be automatically
        # computed and assignated to him.
        #
        # It returns a Reference to this Object.
        # _object_:: The object to add.
        #
        def <<(object)
            owner = object.document

            #
            # Does object belongs to another PDF ?
            #
            if owner and not owner.equal?(self)
                import object
            else
                add_to_revision(object, @revisions.last)
            end
        end
        alias insert <<

        #
        # Similar to PDF#insert or PDF#<<, but for an object belonging to another document.
        # Object will be recursively copied and new version numbers will be assigned.
        # Returns the new reference to the imported object.
        # _object_:: The object to import.
        #
        def import(object)
            self.insert(object.export)
        end

        #
        # Adds a new object to a specific revision.
        # If this object has no version number, then a new one will be automatically
        # computed and assignated to him.
        #
        # It returns a Reference to this Object.
        # _object_:: The object to add.
        # _revision_:: The revision to add the object to.
        #
        def add_to_revision(object, revision)
            object.set_indirect(true)
            object.set_document(self)

            object.no, object.generation = allocate_new_object_number if object.no == 0

            revision.body[object.reference] = object

            object.reference
        end

        #
        # Ends the current Revision, and starts a new one.
        #
        def add_new_revision
            root = @revisions.last.trailer[:Root] unless @revisions.empty?

            @revisions << Revision.new(self)
            @revisions.last.trailer = Trailer.new
            @revisions.last.trailer.Root = root

            self
        end

        #
        # Removes a whole document revision.
        # _index_:: Revision index, first is 0.
        #
        def remove_revision(index)
            if index < 0 or index > @revisions.size
                raise IndexError, "Not a valid revision index"
            end

            if @revisions.size == 1
                raise InvalidPDFError, "Cannot remove last revision"
            end

            @revisions.delete_at(index)
            self
        end

        #
        # Looking for an object present at a specified file offset.
        #
        def get_object_by_offset(offset) #:nodoc:
            self.each_object.find { |obj| obj.file_offset == offset }
        end

        #
        # Remove an object.
        #
        def delete_object(no, generation = 0)
            case no
            when Reference
                target = no
            when ::Integer
                target = Reference.new(no, generation)
            else
                raise TypeError, "Invalid parameter type : #{no.class}"
            end

            @revisions.each do |rev|
                rev.body.delete(target)
            end
        end

        #
        # Search for an indirect object in the document.
        # _no_:: Reference or number of the object.
        # _generation_:: Object generation.
        #
        def get_object(no, generation = 0, use_xrefstm: true) #:nodoc:
            case no
            when Reference
                target = no
            when ::Integer
                target = Reference.new(no, generation)
            when Origami::Object
                return no
            else
                raise TypeError, "Invalid parameter type : #{no.class}"
            end

            #
            # Search through accessible indirect objects.
            #
            @revisions.reverse_each do |rev|
                return rev.body[target] if rev.body.include?(target)
            end

            #
            # Search through xref sections.
            #
            @revisions.reverse_each do |rev|
                next unless rev.xreftable?

                xref = rev.xreftable.find(target.refno)
                next if xref.nil? or xref.free?

                # Try loading the object if it is not present.
                object = load_object_at_offset(rev, xref.offset)
                return object unless object.nil?
            end

            return nil unless use_xrefstm

            # Search through xref streams.
            @revisions.reverse_each do |rev|
                next unless rev.xrefstm?

                xrefstm = rev.xrefstm

                xref = xrefstm.find(target.refno)
                next if xref.nil?

                #
                # We found a matching XRef.
                #
                if xref.is_a?(XRefToCompressedObject)
                    objstm = get_object(xref.objstmno, 0, use_xrefstm: use_xrefstm)

                    object = objstm.extract_by_index(xref.index)
                    if object.is_a?(Origami::Object) and object.no == target.refno
                        return object
                    else
                        return objstm.extract(target.refno)
                    end
                elsif xref.is_a?(XRef)
                    object = load_object_at_offset(rev, xref.offset)
                    return object unless object.nil?
                end
            end

            #
            # Lastly search directly into Object streams (might be very slow).
            #
            @revisions.reverse_each do |rev|
                stream = rev.objects.find{|obj| obj.is_a?(ObjectStream) and obj.include?(target.refno)}
                return stream.extract(target.refno) unless stream.nil?
            end

            nil
        end
        alias [] get_object

        #
        # Casts a PDF object into another object type.
        # The target type must be a subtype of the original type.
        #
        def cast_object(reference, type) #:nodoc:
            @revisions.each do |rev|
                if rev.body.include?(reference)
                    object = rev.body[reference]
                    return object if object.is_a?(type)

                    if type < rev.body[reference].class
                        rev.body[reference] = object.cast_to(type, @parser)

                        return rev.body[reference]
                    end
                end
            end

            nil
        end

        #
        # Returns a new number/generation for future object.
        #
        def allocate_new_object_number

            last_object = self.each_object(compressed: true).max_by {|object| object.no }
            if last_object.nil?
                no = 1
            else
                no = last_object.no + 1
            end

            [ no, 0 ]
        end

        #
        # Mark the document as complete.
        # No more objects needs to be fetched by the parser.
        #
        def loaded!
            @loaded = true
        end

        #
        # Returns if the document as been fully loaded by the parser.
        #
        def loaded?
            @loaded
        end

        ##########################
        private
        ##########################

        #
        # Iterates over the children of an object, avoiding cycles.
        #
        def walk_object(object, excludes: [], &block)
            return enum_for(__method__, object, excludes: excludes) unless block_given?

            return if excludes.include?(object)
            excludes.push(object)

            case object
            when CompoundObject
                object.each_value do |value|
                    yield(value)
                    walk_object(value, excludes: excludes, &block)
                end

            when Stream
                yield(object.dictionary)
                walk_object(object.dictionary, excludes: excludes, &block)
            end
        end

        #
        # Searches through an object, possibly going into object streams.
        # Returns an array of matching strings, names and streams.
        #
        def search_object(object, pattern, streams: true, object_streams: true)
            result = []

            case object
            when Stream
                result.concat object.dictionary.strings_cache.select{|str| str.match(pattern) }
                result.concat object.dictionary.names_cache.select{|name| name.value.match(pattern) }

                begin
                    result.push object if streams and object.data.match(pattern)
                rescue Filter::Error
                    return result # Skip object if a decoding error occured.
                end

                return result unless object.is_a?(ObjectStream) and object_streams

                object.each do |child|
                    result.concat search_object(child, pattern,
                                                streams: streams, object_streams: object_streams)
                end

            when Name, String
                result.push object if object.value.match(pattern)

            when ObjectCache
                result.concat object.strings_cache.select{|str| str.match(pattern) }
                result.concat object.names_cache.select{|name| name.value.match(pattern) }
            end

            result
        end

        #
        # Load an object from its given file offset.
        # The document must have an associated Parser.
        #
        def load_object_at_offset(revision, offset)
            return nil if loaded? or @parser.nil?
            pos = @parser.pos

            begin
                object = @parser.parse_object(offset)
                return nil if object.nil?

                if self.is_a?(Encryption::EncryptedDocument)
                    make_encrypted_object(object)
                end

                add_to_revision(object, revision)
            ensure
                @parser.pos = pos
            end

            object
        end

        #
        # Method called on encrypted objects loaded into the document.
        #
        def make_encrypted_object(object)
            case object
            when String
                object.extend(Encryption::EncryptedString)
            when Stream
                object.extend(Encryption::EncryptedStream)
            when ObjectCache
                object.strings_cache.each do |string|
                    string.extend(Encryption::EncryptedString)
                end
            end
        end

        #
        # Force the loading of all objects in the document.
        #
        def load_all_objects
            return if loaded? or @parser.nil?

            @revisions.each do |revision|
                if revision.xreftable?
                    xrefs = revision.xreftable
                elsif revision.xrefstm?
                    xrefs = revision.xrefstm
                else
                    next
                end

                xrefs.each_with_number do |xref, no|
                    self.get_object(no) unless xref.free?
                end
            end

            loaded!
        end

        #
        # Compute and update XRef::Section for each Revision.
        #
        def rebuild_xrefs
            size = 0
            startxref = @header.to_s.size

            @revisions.each do |revision|
                revision.each_object do |object|
                    startxref += object.to_s.size
                end

                size += revision.body.size
                revision.xreftable = build_xrefs(revision.objects)

                revision.trailer ||= Trailer.new
                revision.trailer.Size = size + 1
                revision.trailer.startxref = startxref

                startxref += revision.xreftable.to_s.size + revision.trailer.to_s.size
            end

            self
        end

        #
        # This method is meant to recompute, verify and correct main PDF structures, in order to output a proper file.
        # * Allocates objects references.
        # * Sets some objects missing required values.
        #
        def compile(options = {})

            load_all_objects unless loaded?

            #
            # A valid document must have at least one page.
            #
            append_page if pages.empty?

            #
            # Allocates object numbers and creates references.
            # Invokes object finalization methods.
            #
            physicalize(options)

            #
            # Sets the PDF version header.
            #
            version, level = version_required
            @header.major_version = version[0,1].to_i
            @header.minor_version = version[2,1].to_i

            set_extension_level(version, level) if level > 0

            self
        end

        #
        # Converts a logical PDF view into a physical view ready for writing.
        #
        def physicalize(options = {})

            @revisions.each do |revision|
                # Do not use each_object here as build_object may modify the iterator.
                revision.objects.each do |obj|
                    build_object(obj, revision, options)
                end
            end

            self
        end

        def build_object(object, revision, options)
            # Build any compressed object before building the object stream.
            if object.is_a?(ObjectStream)
                object.each do |compressed_obj|
                    build_object(compressed_obj, revision, options)
                end
            end

            object.pre_build

            case object
            when Stream
                build_object(object.dictionary, revision, options)
            when CompoundObject
                build_compound_object(object, revision, options)
            end

            object.post_build
        end

        def build_compound_object(object, revision, options)
            return unless object.is_a?(CompoundObject)

            # Flatten the object by adding indirect objects to the revision and
            # replacing them with their reference.
            object.update_values! do |child|
                next(child) unless child.indirect?

                if get_object(child.reference)
                    child.reference
                else
                    reference = add_to_revision(child, revision)
                    build_object(child, revision, options)
                    reference
                end
            end

            # Finalize all the children objects.
            object.each_value do |child|
                build_object(child, revision, options)
            end
        end

        #
        # Returns the final binary representation of the current document.
        #
        def output(params = {})

            has_objstm = self.each_object.any?{|obj| obj.is_a?(ObjectStream)}

            options =
            {
                eol: $/,
                rebuild_xrefs: true,
                noindent: false,
                obfuscate: false,
                use_xrefstm: has_objstm,
                use_xreftable: (not has_objstm),
                up_to_revision: @revisions.size
            }
            options.update(params)

            # Ensures we are using a valid EOL delimiter.
            assert_valid_eol(options[:eol])

            # Do not emit more revisions than present in the document.
            options[:up_to_revision] = [ @revisions.size, options[:up_to_revision] ].min

            # Reset to default params if no xrefs are chosen (hybrid files not supported yet)
            if options[:use_xrefstm] == options[:use_xreftable]
                options[:use_xrefstm] = has_objstm
                options[:use_xreftable] = (not has_objstm)
            end

            # Indent level for objects.
            indent = (options[:noindent] == true ? 0 : 1)

            # Get trailer dictionary
            trailer_dict = self.trailer.dictionary

            prev_xref_offset = nil
            xrefstm_offset = nil

            # Header
            bin = ""
            bin << @header.to_s(eol: options[:eol])

            # For each revision
            @revisions[0, options[:up_to_revision]].each do |rev|

                # Create xref table/stream.
                if options[:rebuild_xrefs] == true
                    lastno_table, lastno_stm = 0, 0
                    brange_table, brange_stm = 0, 0

                    xrefs_stm = [ XRef.new(0, 0, XRef::FREE) ]
                    xrefs_table = [ XRef.new(0, XRef::FIRSTFREE, XRef::FREE) ]

                    if options[:use_xreftable] == true
                        xrefsection = XRef::Section.new
                    end

                    if options[:use_xrefstm] == true
                        xrefstm = rev.xrefstm || XRefStream.new
                        if xrefstm == rev.xrefstm
                            xrefstm.clear
                        else
                            add_to_revision(xrefstm, rev)
                        end
                    end
                end

                objset = rev.objects

                objset.find_all{|obj| obj.is_a?(ObjectStream)}.each do |objstm|
                    objset.concat objstm.objects
                end if options[:rebuild_xrefs] == true and options[:use_xrefstm] == true

                previous_obj = nil

                # For each object, in number order
                # Move any XRefStream to the end of the revision.
                objset.sort_by {|obj| [obj.is_a?(XRefStream) ? 1 : 0, obj.no, obj.generation] }
                      .each do |obj|

                    # Ensures that every object has a unique reference number.
                    # Duplicates should never happen in a well-formed revision and will cause breakage of xrefs.
                    if previous_obj and previous_obj.reference == obj.reference
                        raise InvalidPDFError, "Duplicate object detected, reference #{obj.reference}"
                    else
                        previous_obj = obj
                    end

                    # Create xref entry.
                    if options[:rebuild_xrefs] == true

                        # Adding subsections if needed
                        if options[:use_xreftable] and (obj.no - lastno_table).abs > 1
                            xrefsection << XRef::Subsection.new(brange_table, xrefs_table)

                            xrefs_table.clear
                            brange_table = obj.no
                        end

                        if options[:use_xrefstm] and (obj.no - lastno_stm).abs > 1
                            xrefs_stm.each do |xref| xrefstm << xref end
                            xrefstm.Index ||= []
                            xrefstm.Index << brange_stm << xrefs_stm.length

                            xrefs_stm.clear
                            brange_stm = obj.no
                        end

                        # Process embedded objects
                        if options[:use_xrefstm] and obj.parent != obj and obj.parent.is_a?(ObjectStream)
                            index = obj.parent.index(obj.no)

                            xrefs_stm << XRefToCompressedObject.new(obj.parent.no, index)

                            lastno_stm = obj.no
                        else
                            xrefs_stm << XRef.new(bin.size, obj.generation, XRef::USED)
                            xrefs_table << XRef.new(bin.size, obj.generation, XRef::USED)

                            lastno_table = lastno_stm = obj.no
                        end
                    end

                    if obj.parent == obj or not obj.parent.is_a?(ObjectStream)

                        # Finalize XRefStm
                        if options[:rebuild_xrefs] == true and options[:use_xrefstm] == true and obj == xrefstm
                            xrefstm_offset = bin.size

                            xrefs_stm.each do |xref| xrefstm << xref end

                            xrefstm.W = [ 1, (xrefstm_offset.to_s(2).size + 7) >> 3, 2 ]
                            if xrefstm.DecodeParms.is_a?(Dictionary) and xrefstm.DecodeParms.has_key?(:Columns)
                                xrefstm.DecodeParms[:Columns] = xrefstm.W[0] + xrefstm.W[1] + xrefstm.W[2]
                            end

                            xrefstm.Index ||= []
                            xrefstm.Index << brange_stm << xrefs_stm.size

                            xrefstm.dictionary = xrefstm.dictionary.merge(trailer_dict)
                            xrefstm.Prev = prev_xref_offset
                            rev.trailer.dictionary = nil

                            add_to_revision(xrefstm, rev)

                            xrefstm.pre_build
                            xrefstm.post_build
                        end

                        # Output object code
                        if (obj.is_a?(Dictionary) or obj.is_a?(Stream))
                            bin << obj.to_s(eol: options[:eol], indent: indent)
                        else
                            bin << obj.to_s(eol: options[:eol])
                        end
                    end
                end # end each object

                rev.trailer ||= Trailer.new

                # XRef table
                if options[:rebuild_xrefs] == true

                    if options[:use_xreftable] == true
                        table_offset = bin.size

                        xrefsection << XRef::Subsection.new(brange_table, xrefs_table)
                        rev.xreftable = xrefsection

                        rev.trailer.dictionary = trailer_dict
                        rev.trailer.Size = objset.size + 1
                        rev.trailer.Prev = prev_xref_offset

                        rev.trailer.XRefStm = xrefstm_offset if options[:use_xrefstm] == true
                    end

                    startxref = options[:use_xreftable] == true ? table_offset : xrefstm_offset
                    rev.trailer.startxref = prev_xref_offset = startxref

                end

                # Trailer
                bin << rev.xreftable.to_s(eol: options[:eol]) if options[:use_xreftable] == true
                bin << (options[:obfuscate] == true ? rev.trailer.to_obfuscated_str : rev.trailer.to_s(eol: options[:eol], indent: indent))

            end # end each revision

            bin
        end

        def assert_valid_eol(d)
            allowed = [ "\n", "\r", "\r\n" ]
            unless allowed.include?(d)
                raise ArgumentError, "Invalid EOL delimiter #{d.inspect}, allowed: #{allowed.inspect}"
            end
        end

        #
        # Instanciates basic structures required for a valid PDF file.
        #
        def init
            catalog = (self.Catalog = (trailer_key(:Root) || Catalog.new))
            @revisions.last.trailer.Root = catalog.reference

            loaded!

            self
        end

        def filesize #:nodoc:
            output(rebuild_xrefs: false).size
        end

        def version_required #:nodoc:
            self.each_object.max_by {|obj| obj.version_required}.version_required
        end

        #
        # Compute and update XRef::Section for each Revision.
        #
        def rebuild_dummy_xrefs #:nodoc

            build_dummy_xrefs = -> (objects) do
                lastno = 0
                brange = 0

                xrefs = [ XRef.new(0, XRef::FIRSTFREE, XRef::FREE) ]

                xrefsection = XRef::Section.new
                objects.sort_by {|object| object.reference }
                       .each do |object|

                    if (object.no - lastno).abs > 1
                        xrefsection << XRef::Subsection.new(brange, xrefs)
                        brange = object.no
                        xrefs.clear
                    end

                    xrefs << XRef.new(0, 0, XRef::FREE)

                    lastno = object.no
                end

                xrefsection << XRef::Subsection.new(brange, xrefs)

                xrefsection
            end

            size = 0
            startxref = @header.to_s.size

            @revisions.each do |revision|
                revision.each_object do |object|
                    startxref += object.to_s.size
                end

                size += revision.body.size
                revision.xreftable = build_dummy_xrefs.call(revision.objects)

                revision.trailer ||= Trailer.new
                revision.trailer.Size = size + 1
                revision.trailer.startxref = startxref

                startxref += revision.xreftable.to_s.size + revision.trailer.to_s.size
            end

            self
        end

        #
        # Build a xref section from a set of objects.
        #
        def build_xrefs(objects) #:nodoc:

            lastno = 0
            brange = 0

            xrefs = [ XRef.new(0, XRef::FIRSTFREE, XRef::FREE) ]

            xrefsection = XRef::Section.new
            objects.sort_by {|object| object.reference}
                   .each do |object|

                if (object.no - lastno).abs > 1
                    xrefsection << XRef::Subsection.new(brange, xrefs)
                    brange = object.no
                    xrefs.clear
                end

                xrefs << XRef.new(get_object_offset(object.no, object.generation), object.generation, XRef::USED)

                lastno = object.no
            end

            xrefsection << XRef::Subsection.new(brange, xrefs)

            xrefsection
        end

        def get_object_offset(no, generation) #:nodoc:
            objectoffset = @header.to_s.size

            @revisions.each do |revision|
                revision.objects.sort_by {|object| object.reference }
                                .each do |object|

                    if object.no == no and object.generation == generation then return objectoffset
                    else
                        objectoffset += object.to_s.size
                    end
                end

                objectoffset += revision.xreftable.to_s.size
                objectoffset += revision.trailer.to_s.size
            end

            nil
        end
    end

end
