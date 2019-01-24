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

require 'origami/parsers/ppklite'

require 'openssl'

module Origami

    #
    # Class representing an Adobe Reader certificate store.
    #
    class PPKLite

        class Error < Origami::Error; end

        def self.read(path, options = {})
            path = File.expand_path(path) if path.is_a?(::String)

            PPKLite::Parser.new(options).parse(path)
        end

        #
        # Class representing a certificate store header.
        #
        class Header
            MAGIC = /%PPKLITE-(?<major>\d)\.(?<minor>\d)/

            attr_accessor :major_version, :minor_version

            #
            # Creates a file header, with the given major and minor versions.
            # _major_version_:: Major version.
            # _minor_version_:: Minor version.
            #
            def initialize(major_version = 2, minor_version = 1)
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

                PPKLite::Header.new(maj, min)
            end

            #
            # Outputs self into PDF code.
            #
            def to_s(eol: $/)
                "%PPKLITE-#{@major_version}.#{@minor_version}".b + eol
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

            def initialize(adbk)
                @document = adbk
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

        module Descriptor
            CERTIFICATE = 1
            USER = 2

            def self.included(receiver) #:nodoc:
                receiver.field    :ID,        :Type => Integer, :Required => true
                receiver.field    :ABEType,   :Type => Integer, :Default => Descriptor::CERTIFICATE, :Required => true
            end
        end

        class Certificate < Dictionary
            include StandardObject
            include Descriptor

            add_type_signature :ABEType => Descriptor::CERTIFICATE

            module Flags
                CAN_CERTIFY             = 1 << 1
                ALLOW_DYNAMIC_CONTENT   = 1 << 2
                UNKNOWN_1               = 1 << 3
                ALLOW_HIGH_PRIV_JS      = 1 << 4
                UNKNOWN_2               = 1 << 5
                IS_ROOT_CA              = 1 << 6

                #FULL_TRUST = 1 << 1 | 1 << 2 | 1 << 3 | 1 << 4 | 1 << 5 | 1 << 6
                FULL_TRUST = 8190
            end

            field   :ABEType,       :Type => Integer, :Default => Descriptor::CERTIFICATE, :Required => true
            field   :Usage,         :Type => Integer, :Default => 1, :Required => true
            field   :Viewable,      :Type => Boolean, :Default => true
            field   :Editable,      :Type => Boolean, :Default => true
            field   :Cert,          :Type => String, :Required => true
            field   :Trust,         :Type => Integer, :Default => Flags::UNKNOWN_2, :Required => true
        end

        class User < Dictionary
            include StandardObject
            include Descriptor

            add_type_signature :ABEType => Descriptor::USER

            field   :ABEType,       :Type => Integer, :Default => Descriptor::USER, :Required => true
            field   :Name,          :Type => String, :Required => true
            field   :Encrypt,       :Type => Integer
            field   :Certs,         :Type => Array.of(Certificate), :Default => [], :Required => true
        end

        class AddressList < Dictionary
            include StandardObject

            field   :Type,        :Type => Name, :Default => :AddressBook, :Required => true
            field   :NextID,      :Type => Integer
            field   :Entries,     :Type => Array.of(Descriptor), :Default => [], :Required => true
        end

        class UserList < Dictionary
            include StandardObject

            field   :Type,        :Type => Name, :Default => :User, :Required => true
        end

        class PPK < Dictionary
            include StandardObject

            field   :Type,        :Type => Name, :Default => :PPK, :Required => true
            field   :User,        :Type => UserList, :Required => true
            field   :AddressBook, :Type => AddressList, :Required => true
            field   :V,           :Type => Integer, :Default => 0x10001, :Required => true
        end

        class Catalog < Dictionary
            include StandardObject

            field   :Type,      :Type => Name, :Default => :Catalog, :Required => true
            field   :PPK,       :Type => PPK, :Required => true
        end

        attr_accessor :header, :revisions

        def initialize(parser = nil) #:nodoc:
            @header = PPKLite::Header.new
            @revisions = [ Revision.new(self) ]
            @revisions.first.trailer = Trailer.new
            @parser = parser

            init if parser.nil?
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

        def each_user(&b)
            each_entry(Descriptor::USER, &b)
        end

        def get_user(id)
            self.each_user.find {|user| user.ID == id }
        end

        def users
            self.each_user.to_a
        end

        def each_certificate(&b)
            each_entry(Descriptor::CERTIFICATE, &b)
        end

        def get_certificate(id)
            self.each_certificate.find {|cert| cert.ID == id }
        end

        def certificates
            self.each_certificate.to_a
        end

        #
        # Add a certificate into the address book
        #
        def add_certificate(certfile, attributes, viewable: false, editable: false)
            if certfile.is_a?(OpenSSL::X509::Certificate)
                x509 = certfile
            else
                x509 = OpenSSL::X509::Certificate.new(certfile)
            end

            address_book = get_address_book

            cert = Certificate.new
            cert.Cert = x509.to_der
            cert.ID = address_book.NextID
            address_book.NextID += 1

            cert.Trust = attributes
            cert.Viewable = viewable
            cert.Editable = editable

            address_book.Entries.push(self << cert)
        end

        private

        def init
            catalog = Catalog.new(
                PPK: PPK.new(
                    User: UserList.new,
                    AddressBook: AddressList.new(
                        Entries: [],
                        NextID: 1
                    )
                )
            )

            @revisions.first.trailer.Root = self.insert(catalog)
        end

        def each_entry(type)
            return enum_for(__method__, type) unless block_given?

            address_book = get_address_book 

            address_book.Entries.each do |entry|
                entry = entry.solve

                yield(entry) if entry.is_a?(Dictionary) and entry.ABEType == type
            end
        end

        def get_address_book
            raise Error, "Broken catalog" unless self.Catalog.is_a?(Dictionary) and self.Catalog.PPK.is_a?(Dictionary)

            ppk = self.Catalog.PPK
            raise Error, "Broken PPK" unless ppk.AddressBook.is_a?(Dictionary)

            address_book = ppk.AddressBook
            raise Error, "Broken address book" unless address_book.Entries.is_a?(Array)

            address_book
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
