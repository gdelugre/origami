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
require 'origami/name'
require 'origami/dictionary'
require 'origami/reference'
require 'origami/boolean'
require 'origami/numeric'
require 'origami/string'
require 'origami/array'
require 'origami/trailer'
require 'origami/xreftable'

require 'origami/parsers/fdf'

module Origami

    #
    # Class representing an AcroForm Forms Data Format file.
    #
    class FDF

        def self.read(path, options = {})
            path = File.expand_path(path) if path.is_a?(::String)

            FDF::Parser.new(options).parse(path)
        end

        class Header
            MAGIC = /%FDF-(?<major>\d)\.(?<minor>\d)/

            attr_accessor :major_version, :minor_version

            #
            # Creates a file header, with the given major and minor versions.
            # _major_version_:: Major version.
            # _minor_version_:: Minor version.
            #
            def initialize(major_version = 1, minor_version = 2)
                @major_version, @minor_version = major_version, minor_version
            end

            def self.parse(stream) #:nodoc:
                scanner = Parser.init_scanner(stream)

                if not scanner.scan(MAGIC).nil?
                    maj = scanner['major'].to_i
                    min = scanner['minor'].to_i
                else
                    raise InvalidHeader, "Invalid header format"
                end

                scanner.skip(REGEXP_WHITESPACES)

                FDF::Header.new(maj, min)
            end

            def to_s(eol: $/)
                "%FDF-#{@major_version}.#{@minor_version}".b + eol
            end

            def to_sym #:nodoc:
                "#{@major_version}.#{@minor_version}".to_sym
            end

            def to_f #:nodoc:
                to_sym.to_s.to_f
            end
        end

        class Revision #:nodoc;
            attr_accessor :document
            attr_accessor :body, :xreftable
            attr_reader :trailer

            def initialize(fdf)
                @document = fdf
                @body = {}
                @xreftable = nil
                @trailer = nil
            end

            def trailer=(trl)
                trl.document = @document
                @trailer = trl
            end

            def each_object(&b)
                @body.each_value(&b)
            end

            def objects
                @body.values
            end
        end

        class JavaScript < Dictionary
            include StandardObject

            field   :Before,            :Type => [ String, Stream ]
            field   :After,             :Type => [ String, Stream ]
            field   :AfterPermsReady,   :Type => [ String, Stream ]
            field   :Doc,               :Type => Array.of(Name, String)
        end
        
        class IconFit < Dictionary
            include StandardObject
           
            ALWAYS_SCALE        = :A
            SCALE_WHEN_BIGGER   = :B
            SCALE_WHEN_SMALLER  = :S
            NEVER_SCALE         = :N
            
            field   :SW,                :Type => Name
            field   :S,                 :Type => Name
            field   :A,                 :Type => Array.of(Number, length: 2)
            field   :FB,                :Type => Boolean
        end
        
        class NamedPageReference < Dictionary
             include StandardObject

             field  :Name,              :Type => String, :Required => true
             field  :F,                 :Type => FileSpec
        end

        class Field < Dictionary
            include StandardObject

            field   :Kids,              :Type => Array.of(Field)
            field   :T,                 :Type => String, :Required => true
            field   :V,                 :Type => Dictionary
            field   :Ff,                :Type => Integer
            field   :SetFf,             :Type => Integer
            field   :ClrFf,             :Type => Integer
            field   :F,                 :Type => Integer
            field   :SetF,              :Type => Integer
            field   :ClrF,              :Type => Integer
            field   :AP,                :Type => Annotation::AppearanceDictionary
            field   :APRef,             :Type => Dictionary
            field   :IF,                :Type => IconFit
            field   :Opt,               :Type => Array.of([String, Array.of(String, String)])
            field   :A,                 :Type => Action
            field   :AA,                :Type => Annotation::AdditionalActions
            field   :RV,                :Type => [ String, Stream ]
        end
        
        class Template < Dictionary
            include StandardObject

            field   :TRef,              :Type => NamedPageReference, :Required => true
            field   :Fields,            :Type => Array.of(Field)
            field   :Rename,            :Type => Boolean
        end
        
        class Page < Dictionary
            include StandardObject

            field   :Templates,         :Type => Array.of(Template), :Required => true
            field   :Info,              :Type => Dictionary
        end

        class Annotation < Origami::Annotation
            field   :Page,              :Type => Integer, :Required => true
        end
        
        class Dictionary < Origami::Dictionary
            include StandardObject

            field   :F,                 :Type => FileSpec
            field   :ID,                :Type => Array.of(String, length: 2)
            field   :Fields,            :Type => Array.of(FDF::Field)
            field   :Status,            :Type => String
            field   :Pages,             :Type => Array.of(FDF::Page)
            field   :Encoding,          :Type => Name
            field   :Annots,            :Type => Array.of(FDF::Annotation)
            field   :Differences,       :Type => Stream
            field   :Target,            :Type => String
            field   :EmbeddedFDFs,      :Type => Array.of(FileSpec)
            field   :JavaScript,        :Type => JavaScript
        end
        
        class Catalog < Dictionary
            include StandardObject

            field   :Version,       :Type => Name
            field   :FDF,           :Type => FDF::Dictionary, :Required => true
        end

        attr_accessor :header, :revisions

        def initialize(parser = nil) #:nodoc:
            @header = FDF::Header.new
            @revisions = [ Revision.new(self) ]
            @revisions.first.trailer = Trailer.new
            @parser = parser

            init if parser.nil?
        end

        def <<(object)
            object.set_indirect(true)
            object.set_document(self)

            if object.no.zero?
                maxno = 1
                maxno = maxno.succ while get_object(maxno)

                object.generation = 0
                object.no = maxno
            end

            @revisions.first.body[object.reference] = object

            object.reference
        end
        alias insert <<

        def get_object(no, generation = 0) #:nodoc:
            case no
            when Reference
              target = no
            when ::Integer
              target = Reference.new(no, generation)
            when Origami::Object
              return no
            end

            @revisions.first.body[target]
        end

        def indirect_objects
            @revisions.inject([]) do |set, rev| set.concat(rev.objects) end
        end
        alias root_objects indirect_objects

        def cast_object(reference, type) #:nodoc:
            @revisions.each do |rev|
                if rev.body.include?(reference) and type < rev.body[reference].class
                    rev.body[reference] = rev.body[reference].cast_to(type, @parser)

                    rev.body[reference]
                else
                    nil
                end
            end
        end

        def Catalog
            get_object(@revisions.first.trailer.Root)
        end

        def save(path)
            bin = "".b
            bin << @header.to_s

            lastno, brange = 0, 0

            xrefs = [ XRef.new(0, XRef::FIRSTFREE, XRef::FREE) ]
            xrefsection = XRef::Section.new

            @revisions.first.body.values.sort.each { |obj|
                if (obj.no - lastno).abs > 1
                    xrefsection << XRef::Subsection.new(brange, xrefs)
                    brange = obj.no
                    xrefs.clear
                end

                xrefs << XRef.new(bin.size, obj.generation, XRef::USED)
                lastno = obj.no

                obj.pre_build

                bin << obj.to_s

                obj.post_build
            }

            xrefsection << XRef::Subsection.new(brange, xrefs)

            @xreftable = xrefsection
            @trailer ||= Trailer.new
            @trailer.Size = @revisions.first.body.size + 1
            @trailer.startxref = bin.size

            bin << @xreftable.to_s
            bin << @trailer.to_s

            if path.respond_to?(:write)
                io = path
            else
                path = File.expand_path(path)
                io = File.open(path, "wb", encoding: 'binary')
                close = true
            end

            begin
                io.write(bin)
            ensure
                io.close if close
            end

            self
        end

        private

        def init
            catalog = Catalog.new(:FDF => FDF::Dictionary.new)

            @revisions.first.trailer.Root = self.insert(catalog)
        end

        def get_object_offset(no,generation) #:nodoc:
            bodyoffset = @header.to_s.size
            objectoffset = bodyoffset

            @revisions.first.body.values.each { |object|
                if object.no == no and object.generation == generation then return objectoffset
                else
                    objectoffset += object.to_s.size
                end
            }

            nil
        end
        
    end
end
