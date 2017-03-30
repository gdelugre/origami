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
        # Returns true if the document contains an acrobat form.
        #
        def form?
            self.Catalog.key? :AcroForm
        end

        #
        # Creates a new AcroForm with specified fields.
        #
        def create_form(*fields)
            acroform = self.Catalog.AcroForm ||= InteractiveForm.new.set_indirect(true)
            self.add_fields(*fields)

            acroform
        end

        #
        # Add a field to the Acrobat form.
        # _field_:: The Field to add.
        #
        def add_fields(*fields)
            raise TypeError, "Expected Field arguments" unless fields.all? { |f| f.is_a?(Field) }

            self.Catalog.AcroForm ||= InteractiveForm.new.set_indirect(true)
            self.Catalog.AcroForm.Fields ||= []

            self.Catalog.AcroForm.Fields.concat(fields)
            fields.each do |field| field.set_indirect(true) end

            self
        end

        #
        # Returns an Array of Acroform fields.
        #
        def fields
            self.each_field.to_a
        end

        #
        # Iterates over each Acroform Field.
        #
        def each_field
            return enum_for(__method__) do
                if self.form? and self.Catalog.AcroForm.Fields.is_a?(Array)
                    self.Catalog.AcroForm.Fields.length
                else
                    0
                end
            end unless block_given?

            if self.form? and self.Catalog.AcroForm.Fields.is_a?(Array)
                self.Catalog.AcroForm.Fields.each do |field|
                    yield(field.solve)
                end
            end
        end

        #
        # Returns the corresponding named Field.
        #
        def get_field(name)
            self.each_field do |field|
                return field if field[:T].solve == name
            end

            nil
        end
    end

    #
    # Class representing a interactive form Dictionary.
    #
    class InteractiveForm < Dictionary
        include StandardObject

        #
        # Flags relative to signature fields.
        #
        module SigFlags
            SIGNATURES_EXIST = 1 << 0
            APPEND_ONLY      = 1 << 1
        end

        field   :Fields,            :Type => Array, :Required => true, :Default => []
        field   :NeedAppearances,   :Type => Boolean, :Default => false
        field   :SigFlags,          :Type => Integer, :Default => 0
        field   :CO,                :Type => Array, :Version => "1.3"
        field   :DR,                :Type => Dictionary
        field   :DA,                :Type => String
        field   :Q,                 :Type => Integer
        field   :XFA,               :Type => [ XFAStream, Array.of(String, XFAStream) ]
    end

    module Field
        #
        # Types of fields.
        #
        module Type
            BUTTON      = :Btn
            TEXT        = :Tx
            CHOICE      = :Ch
            SIGNATURE   = :Sig
        end

        #
        # Flags relative to fields.
        #
        module Flags
            READONLY = 1 << 0
            REQUIRED = 1 << 1
            NOEXPORT = 1 << 2
        end

        module TextAlign
            LEFT    = 0
            CENTER  = 1
            RIGHT   = 2
        end

        class AdditionalActions < Dictionary
            include StandardObject

            field   :K,     :Type => Dictionary, :Version => "1.3"
            field   :F,     :Type => Dictionary, :Version => "1.3"
            field   :V,     :Type => Dictionary, :Version => "1.3"
            field   :C,     :Type => Dictionary, :Version => "1.3"
        end

        def self.included(receiver) #:nodoc:
            receiver.field   :FT,     :Type => Name, :Required => true
            receiver.field   :Parent, :Type => Field
            receiver.field   :Kids,   :Type => Array.of(Field)
            receiver.field   :T,      :Type => String
            receiver.field   :TU,     :Type => String, :Version => "1.3"
            receiver.field   :TM,     :Type => String, :Version => "1.3"
            receiver.field   :Ff,     :Type => Integer, :Default => 0
            receiver.field   :V,      :Type => Object
            receiver.field   :DV,     :Type => Object
            receiver.field   :AA,     :Type => AdditionalActions, :Version => "1.2"

            # Variable text fields
            receiver.field   :DA,     :Type => String, :Default => "/F1 10 Tf 0 g", :Required => true
            receiver.field   :Q,      :Type => Integer, :Default => TextAlign::LEFT
            receiver.field   :DS,     :Type => String, :Version => "1.5"
            receiver.field   :RV,     :Type => [ String, Stream ], :Version => "1.5"
        end

        def pre_build #:nodoc:
            unless self.key?(:T)
                self.set_name "field#{self.object_id}"
            end

            super
        end

        #
        # Sets the (partial) name of the field.
        #
        def set_name(field_name)
            self.T = field_name
            self
        end

        #
        # Sets the (partial) name of the field.
        #
        def name=(field_name)
            self.T = field_name
        end

        #
        # Returns the (partial) name of the field.
        #
        def name
            self.T
        end

        def onKeyStroke(action)
            unless action.is_a?(Action)
                raise TypeError, "An Action object must be passed."
            end

            self.AA ||= AdditionalActions.new
            self.AA.K = action
        end

        def onFormat(action)
            unless action.is_a?(Action)
                raise TypeError, "An Action object must be passed."
            end

            self.AA ||= AdditionalActions.new
            self.AA.F = action
        end

        def onValidate(action)
            unless action.is_a?(Action)
                raise TypeError, "An Action object must be passed."
            end

            self.AA ||= AdditionalActions.new
            self.AA.V = action
        end

        def onCalculate(action)
            unless action.is_a?(Action)
                raise TypeError, "An Action object must be passed."
            end

            self.AA ||= AdditionalActions.new
            self.AA.C = action
        end

        class Subform < Dictionary
            include StandardObject
            include Field

            def add_fields(*fields)
                self.Kids ||= []
                self.Kids.concat(fields)

                fields.each { |field| field.Parent = self }

                self
            end
        end

        class SignatureLock < Dictionary
            include StandardObject

            module Actions
                ALL     = :All
                INCLUDE = :Include
                EXCLUDE = :Exclude
            end

            field   :Type,            :Type => Name, :Default => :SigFieldLock
            field   :Action,          :Type => Name, :Required => true
            field   :Fields,          :Type => Array

            def pre_build
                if self.Action and self.Action != Actions::ALL
                    self.Fields ||= []
                end

                super
            end
        end

        class SignatureSeedValue < Dictionary
            include StandardObject

            module Digest
                SHA1        = :SHA1
                SHA256      = :SHA256
                SHA384      = :SHA384
                SHA512      = :SHA512
                RIPEMD160   = :RIPEMD160
            end

            field   :Type,            :Type => Name, :Default => :SV
            field   :Filter,          :Type => Name
            field   :SubFilter,       :Type => Array
            field   :DigestMethod,    :Type => Array, :Default => Digest::SHA1, :Version => "1.7"
            field   :V,               :Type => Real, :Default => 1.0
            field   :Cert,            :Type => Dictionary
            field   :Reasons,         :Type => Array
            field   :MDP,             :Type => Dictionary, :Version => "1.6"
            field   :TimeStamp,       :Type => Dictionary, :Version => "1.6"
            field   :LegalAttestation,  :Type => Array, :Version => "1.6"
            field   :AddRevInfo,      :Type => Boolean, :Default => false, :Version => "1.7"
            field   :Ff,              :Type => Integer, :Default => 0
        end

        class CertificateSeedValue < Dictionary
            include StandardObject

            module URL
                BROWSER = :Browser
                ASSP    = :ASSP
            end

            field   :Type,            :Type => Name, :Default => :SVCert
            field   :Subject,         :Type => Array
            field   :SubjectDN,       :Type => Array, :Version => "1.7"
            field   :KeyUsage,        :Type => Array, :Version => "1.7"
            field   :Issuer,          :Type => Array
            field   :OID,             :Type => Array
            field   :URL,             :Type => String
            field   :URLType,         :Type => Name, :Default => URL::BROWSER, :Version => "1.7"
            field   :Ff,              :Type => Integer, :Default => 0
        end
    end

end
