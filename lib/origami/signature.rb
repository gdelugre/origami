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

require 'openssl'
require 'digest/sha1'

module Origami

    class PDF
        class SignatureError < Error #:nodoc:
        end

        #
        # Verify a document signature.
        #   _:trusted_certs_: an array of trusted X509 certificates.
        #   If no argument is passed, embedded certificates are treated as trusted.
        #
        def verify(trusted_certs: [])
            digsig = self.signature

            unless digsig[:Contents].is_a?(String)
                raise SignatureError, "Invalid digital signature contents"
            end

            store = OpenSSL::X509::Store.new
            trusted_certs.each do |ca| store.add_cert(ca) end
            flags = 0
            flags |= OpenSSL::PKCS7::NOVERIFY if trusted_certs.empty?

            stream = StringScanner.new(self.original_data)
            stream.pos = digsig[:Contents].file_offset
            Object.typeof(stream).parse(stream)
            endofsig_offset = stream.pos
            stream.terminate

            s1,l1,s2,l2 = digsig.ByteRange
            if s1.value != 0 or
                (s2.value + l2.value) != self.original_data.size or
                (s1.value + l1.value) != digsig[:Contents].file_offset or
                s2.value != endofsig_offset

                raise SignatureError, "Invalid signature byte range"
            end

            data = self.original_data[s1,l1] + self.original_data[s2,l2]

            case digsig.SubFilter.value.to_s
            when 'adbe.pkcs7.detached'
                flags |= OpenSSL::PKCS7::DETACHED
                p7 = OpenSSL::PKCS7.new(digsig[:Contents].value)
                raise SignatureError, "Not a PKCS7 detached signature" unless p7.detached?
                p7.verify([], store, data, flags)

            when 'adbe.pkcs7.sha1'
                p7 = OpenSSL::PKCS7.new(digsig[:Contents].value)
                p7.verify([], store, nil, flags) and p7.data == Digest::SHA1.digest(data)

            else
                raise NotImplementedError, "Unsupported method #{digsig.SubFilter}"
            end
        end

        #
        # Sign the document with the given key and x509 certificate.
        # _certificate_:: The X509 certificate containing the public key.
        # _key_:: The private key associated with the certificate.
        # _method_:: The PDF signature identifier.
        # _ca_:: Optional CA certificates used to sign the user certificate.
        # _annotation_:: Annotation associated with the signature.
        # _issuer_:: Issuer name.
        # _location_:: Signature location.
        # _contact_:: Signer contact.
        # _reason_:: Signing reason.
        #
        def sign(certificate, key,
                 method: "adbe.pkcs7.detached",
                 ca: [],
                 annotation: nil,
                 issuer: nil,
                 location: nil,
                 contact: nil,
                 reason: nil)

            unless certificate.is_a?(OpenSSL::X509::Certificate)
                raise TypeError, "A OpenSSL::X509::Certificate object must be passed."
            end

            unless key.is_a?(OpenSSL::PKey::RSA)
                raise TypeError, "A OpenSSL::PKey::RSA object must be passed."
            end

            unless ca.is_a?(::Array)
                raise TypeError, "Expected an Array of CA certificate."
            end

            unless annotation.nil? or annotation.is_a?(Annotation::Widget::Signature)
                raise TypeError, "Expected a Annotation::Widget::Signature object."
            end

            case method
            when 'adbe.pkcs7.detached'
                signfield_size = -> (crt, pkey, certs) do
                    OpenSSL::PKCS7.sign(
                        crt,
                        pkey,
                        "",
                        certs,
                        OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY
                    ).to_der.size
                end

            when 'adbe.pkcs7.sha1'
              signfield_size = -> (crt, pkey, certs) do
                    OpenSSL::PKCS7.sign(
                        crt,
                        pkey,
                        Digest::SHA1.digest(''),
                        certs,
                        OpenSSL::PKCS7::BINARY
                    ).to_der.size
                end

            when 'adbe.x509.rsa_sha1'
                signfield_size = -> (_crt, pkey, _certs) do
                    pkey.private_encrypt(
                      Digest::SHA1.digest('')
                    ).size
                end
                raise NotImplementedError, "Unsupported method #{method.inspect}"

            else
                raise NotImplementedError, "Unsupported method #{method.inspect}"
            end

            digsig = Signature::DigitalSignature.new.set_indirect(true)

            if annotation.nil?
                annotation = Annotation::Widget::Signature.new
                annotation.Rect = Rectangle[:llx => 0.0, :lly => 0.0, :urx => 0.0, :ury => 0.0]
            end

            annotation.V = digsig
            add_fields(annotation)
            self.Catalog.AcroForm.SigFlags =
                InteractiveForm::SigFlags::SIGNATURESEXIST | InteractiveForm::SigFlags::APPENDONLY

            digsig.Type = :Sig #:nodoc:
            digsig.Contents = HexaString.new("\x00" * signfield_size[certificate, key, ca]) #:nodoc:
            digsig.Filter = :"Adobe.PPKLite" #:nodoc:
            digsig.SubFilter = Name.new(method) #:nodoc:
            digsig.ByteRange = [0, 0, 0, 0] #:nodoc:
            digsig.Name = issuer

            digsig.Location = HexaString.new(location) if location
            digsig.ContactInfo = HexaString.new(contact) if contact
            digsig.Reason = HexaString.new(reason) if reason

            if method == 'adbe.x509.rsa_sha1'
                digsig.Cert =
                    if ca.empty?
                        HexaString.new(certificate.to_der)
                    else
                        [ HexaString.new(certificate.to_der) ] + ca.map{ |crt| HexaString.new(crt.to_der) }
                    end
            end

            #
            #  Flattening the PDF to get file view.
            #
            compile

            #
            # Creating an empty Xref table to compute signature byte range.
            #
            rebuild_dummy_xrefs

            sig_offset = get_object_offset(digsig.no, digsig.generation) + digsig.signature_offset

            digsig.ByteRange[0] = 0
            digsig.ByteRange[1] = sig_offset
            digsig.ByteRange[2] = sig_offset + digsig.Contents.to_s.bytesize

            until digsig.ByteRange[3] == filesize - digsig.ByteRange[2]
                digsig.ByteRange[3] = filesize - digsig.ByteRange[2]
            end

            # From that point on, the file size remains constant

            #
            # Correct Xrefs variations caused by ByteRange modifications.
            #
            rebuild_xrefs

            file_data = output()
            signable_data = file_data[digsig.ByteRange[0],digsig.ByteRange[1]] +
                file_data[digsig.ByteRange[2],digsig.ByteRange[3]]

            signature =
                case method
                when 'adbe.pkcs7.detached'
                    OpenSSL::PKCS7.sign(
                        certificate,
                        key,
                        signable_data,
                        ca,
                        OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY
                    ).to_der

                when 'adbe.pkcs7.sha1'
                    OpenSSL::PKCS7.sign(
                        certificate,
                        key,
                        Digest::SHA1.digest(signable_data),
                        ca,
                        OpenSSL::PKCS7::BINARY
                    ).to_der

                when 'adbe.x509.rsa_sha1'
                    key.private_encrypt(Digest::SHA1.digest(signable_data))
                end

            digsig.Contents[0, signature.size] = signature

            #
            # No more modification are allowed after signing.
            #
            self.freeze
        end

        #
        # Returns whether the document contains a digital signature.
        #
        def signed?
            begin
                self.Catalog.AcroForm.is_a?(Dictionary) and
                self.Catalog.AcroForm.has_key?(:SigFlags) and
                (self.Catalog.AcroForm.SigFlags & InteractiveForm::SigFlags::SIGNATURESEXIST != 0)
            rescue InvalidReferenceError
                false
            end
        end

        #
        # Enable the document Usage Rights.
        # _rights_:: list of rights defined in UsageRights::Rights
        #
        def enable_usage_rights(cert, pkey, *rights)

            signfield_size = -> (crt, key, ca) do
                OpenSSL::PKCS7.sign(
                    crt,
                    key,
                    '',
                    ca,
                    OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY
                ).to_der.size
            end

            #
            # Load key pair
            #
            key = pkey.is_a?(OpenSSL::PKey::RSA) ? pkey : OpenSSL::PKey::RSA.new(pkey)
            certificate = cert.is_a?(OpenSSL::X509::Certificate) ? cert : OpenSSL::X509::Certificate.new(cert)

            #
            # Forge digital signature dictionary
            #
            digsig = Signature::DigitalSignature.new.set_indirect(true)

            self.Catalog.AcroForm ||= InteractiveForm.new
            #self.Catalog.AcroForm.SigFlags = InteractiveForm::SigFlags::APPENDONLY

            digsig.Type = :Sig #:nodoc:
            digsig.Contents = HexaString.new("\x00" * signfield_size[certificate, key, []]) #:nodoc:
            digsig.Filter = :"Adobe.PPKLite" #:nodoc:
            digsig.Name = "ARE Acrobat Product v8.0 P23 0002337" #:nodoc:
            digsig.SubFilter = :"adbe.pkcs7.detached" #:nodoc:
            digsig.ByteRange = [0, 0, 0, 0] #:nodoc:

            sigref = Signature::Reference.new #:nodoc:
            sigref.Type = :SigRef #:nodoc:
            sigref.TransformMethod = :UR3 #:nodoc:
            sigref.Data = self.Catalog

            sigref.TransformParams = UsageRights::TransformParams.new
            sigref.TransformParams.P = true #:nodoc:
            sigref.TransformParams.Type = :TransformParams #:nodoc:
            sigref.TransformParams.V = UsageRights::TransformParams::VERSION

            rights.each do |right|
                sigref.TransformParams[right.first] ||= []
                sigref.TransformParams[right.first].concat(right[1..-1])
            end

            digsig.Reference = [ sigref ]

            self.Catalog.Perms ||= Perms.new
            self.Catalog.Perms.UR3 = digsig

            #
            #  Flattening the PDF to get file view.
            #
            compile

            #
            # Creating an empty Xref table to compute signature byte range.
            #
            rebuild_dummy_xrefs

            sig_offset = get_object_offset(digsig.no, digsig.generation) + digsig.signature_offset

            digsig.ByteRange[0] = 0
            digsig.ByteRange[1] = sig_offset
            digsig.ByteRange[2] = sig_offset + digsig.Contents.size

            until digsig.ByteRange[3] == filesize - digsig.ByteRange[2]
                digsig.ByteRange[3] = filesize - digsig.ByteRange[2]
            end

            # From that point on, the file size remains constant

            #
            # Correct Xrefs variations caused by ByteRange modifications.
            #
            rebuild_xrefs

            file_data = output()
            signable_data = file_data[digsig.ByteRange[0],digsig.ByteRange[1]] +
                file_data[digsig.ByteRange[2],digsig.ByteRange[3]]

            signature = OpenSSL::PKCS7.sign(
                certificate,
                key,
                signable_data,
                [],
                OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY
            ).to_der
            digsig.Contents[0, signature.size] = signature

            #
            # No more modification are allowed after signing.
            #
            self.freeze
        end

        def usage_rights?
            not self.Catalog.Perms.nil? and
                (not self.Catalog.Perms.has_key?(:UR3) or not self.Catalog.Perms.has_key?(:UR))
        end

        def signature
            raise SignatureError, "Not a signed document" unless self.signed?

            self.each_field do |field|
                return field.V if field.FT == :Sig and field.V.is_a?(Dictionary)
            end

            raise SignatureError, "Cannot find digital signature"
        end
    end

    class Perms < Dictionary
        include StandardObject

        field   :DocMDP,          :Type => Dictionary
        field   :UR,              :Type => Dictionary
        field   :UR3,             :Type => Dictionary, :Version => "1.6"
    end

    module Signature

        #
        # Class representing a signature which can be embedded in DigitalSignature dictionary.
        # It must be a direct object.
        #
        class Reference < Dictionary
            include StandardObject

            field   :Type,            :Type => Name, :Default => :SigRef
            field   :TransformMethod, :Type => Name, :Default => :DocMDP, :Required => true
            field   :TransformParams, :Type => Dictionary
            field   :Data,            :Type => Object
            field   :DigestMethod,    :Type => Name, :Default => :MD5
            field   :DigestValue,     :Type => String
            field   :DigestLocation,  :Type => Array

            def initialize(hash = {}, parser = nil)
                set_indirect(false)

                super(hash, parser)
            end
        end

        class BuildData < Dictionary
            include StandardObject

            field   :Name,              :Type => Name,  :Version => "1.5"
            field   :Date,              :Type => String, :Version => "1.5"
            field   :R,                 :Type => Number, :Version => "1.5"
            field   :PreRelease,        :Type => Boolean, :Default => false, :Version => "1.5"
            field   :OS,                :Type => Array, :Version => "1.5"
            field   :NonEFontNoWarn,    :Type => Boolean, :Version => "1.5"
            field   :TrustedMode,       :Type => Boolean, :Version => "1.5"
            field   :V,                 :Type => Number, :Version => "1.5"

            def initialize(hash = {}, parser = nil)
                set_indirect(false)

                super(hash, parser)
            end
        end

        class AppData < BuildData
            field   :REx,               :Type => String, :Version => "1.6"
        end

        class SigQData < BuildData
            field   :Preview,           :Type => Boolean, :Default => false, :Version => "1.7"
        end

        class BuildProperties < Dictionary
            include StandardObject

            field   :Filter,          :Type => BuildData, :Version => "1.5"
            field   :PubSec,          :Type => BuildData, :Version => "1.5"
            field   :App,             :Type => AppData, :Version => "1.5"
            field   :SigQ,            :Type => SigQData, :Version => "1.7"

            def initialize(hash = {}, parser = nil)
                set_indirect(false)

                super(hash, parser)
            end

            def pre_build #:nodoc:
                self.Filter ||= BuildData.new
                self.Filter.Name ||= :"Adobe.PPKLite"
                self.Filter.R ||= 0x20020
                self.Filter.V ||= 2
                self.Filter.Date ||= Time.now.to_s

                self.PubSec ||= BuildData.new
                self.PubSec.NonEFontNoWarn ||= true
                self.PubSec.Date ||= Time.now.to_s
                self.PubSec.R ||= 0x20021

                self.App ||= AppData.new
                self.App.Name ||= :Reader
                self.App.REx = "11.0.8"
                self.App.TrustedMode ||= true
                self.App.OS ||= [ :Win ]
                self.App.R ||= 0xb0008

                super
            end
        end

        #
        # Class representing a digital signature.
        #
        class DigitalSignature < Dictionary
            include StandardObject

            field   :Type,            :Type => Name, :Default => :Sig
            field   :Filter,          :Type => Name, :Default => :"Adobe.PPKLite", :Required => true
            field   :SubFilter,       :Type => Name
            field   :Contents,        :Type => String, :Required => true
            field   :Cert,            :Type => [ String, Array.of(String) ]
            field   :ByteRange,       :Type => Array.of(Integer, length: 4)
            field   :Reference,       :Type => Array.of(Reference), :Version => "1.5"
            field   :Changes,         :Type => Array
            field   :Name,            :Type => String
            field   :M,               :Type => String
            field   :Location,        :Type => String
            field   :Reason,          :Type => String
            field   :ContactInfo,     :Type => String
            field   :R,               :Type => Integer
            field   :V,               :Type => Integer, :Default => 0, :Version => "1.5"
            field   :Prop_Build,      :Type => BuildProperties, :Version => "1.5"
            field   :Prop_AuthTime,   :Type => Integer, :Version => "1.5"
            field   :Prop_AuthType,   :Type => Name, :Version => "1.5"

            def pre_build #:nodoc:
                self.M = Origami::Date.now
                self.Prop_Build ||= BuildProperties.new.pre_build

                super
            end

            def to_s(indent: 1, tab: "\t") #:nodoc:

                # Must be deterministic.
                indent, tab = 1, "\t"

                content = TOKENS.first + EOL

                self.to_a.sort_by{ |key, _| key }.reverse.each do |key, value|
                    content << tab * indent << key.to_s << " "
                    content << (value.is_a?(Dictionary) ? value.to_s(indent: indent + 1) : value.to_s) << EOL
                end

                content << tab * (indent - 1) << TOKENS.last

                output(content)
            end

            def signature_offset #:nodoc:
                indent, tab = 1, "\t"
                content = "#{no} #{generation} obj" + EOL + TOKENS.first + EOL

                self.to_a.sort_by{ |key, _| key }.reverse.each do |key, value|
                    if key == :Contents
                        content << tab * indent + key.to_s + " "

                        return content.size
                    else
                        content << tab * indent + key.to_s << " "
                        content << (value.is_a?(Dictionary) ? value.to_s(indent: indent + 1) : value.to_s) << EOL
                    end
                end

                nil
            end
        end

    end

    module UsageRights

        module Rights
            DOCUMENT_FULLSAVE = %i[Document FullSave]
            DOCUMENT_ALL = DOCUMENT_FULLSAVE

            ANNOTS_CREATE = %i[Annots Create]
            ANNOTS_DELETE = %i[Annots Delete]
            ANNOTS_MODIFY = %i[Annots Modify]
            ANNOTS_COPY = %i[Annots Copy]
            ANNOTS_IMPORT = %i[Annots Import]
            ANNOTS_EXPORT = %i[Annots Export]
            ANNOTS_ONLINE = %i[Annots Online]
            ANNOTS_SUMMARYVIEW = %i[Annots SummaryView]
            ANNOTS_ALL = %i[Annots Create Modify Copy Import Export Online SummaryView]

            FORM_FILLIN = %i[Form FillIn]
            FORM_IMPORT = %i[Form Import]
            FORM_EXPORT = %i[Form Export]
            FORM_SUBMITSTANDALONE = %i[Form SubmitStandAlone]
            FORM_SPAWNTEMPLATE = %i[Form SpawnTemplate]
            FORM_BARCODEPLAINTEXT = %i[Form BarcodePlaintext]
            FORM_ONLINE = %i[Form Online]
            FORM_ALL = %i[Form FillIn Import Export SubmitStandAlone SpawnTemplate BarcodePlaintext Online]

            FORMEX_BARCODEPLAINTEXT = %i[FormEx BarcodePlaintext]
            FORMEX_ALL = FORMEX_BARCODEPLAINTEXT

            SIGNATURE_MODIFY = %i[Signature Modify]
            SIGNATURE_ALL = SIGNATURE_MODIFY

            EF_CREATE = %i[EF Create]
            EF_DELETE = %i[EF Delete]
            EF_MODIFY = %i[EF Modify]
            EF_IMPORT = %i[EF Import]
            EF_ALL = %i[EF Create Delete Modify Import]

            ALL = [ DOCUMENT_ALL, ANNOTS_ALL, FORM_ALL, SIGNATURE_ALL, EF_ALL ]
        end

        class TransformParams < Dictionary
            include StandardObject

            VERSION = Name.new("2.2")

            field   :Type,              :Type => Name, :Default => :TransformParams
            field   :Document,          :Type => Array.of(Name)
            field   :Msg,               :Type => String
            field   :V,                 :Type => Name, :Default => VERSION
            field   :Annots,            :Type => Array.of(Name)
            field   :Form,              :Type => Array.of(Name)
            field   :FormEx,            :Type => Array.of(Name)
            field   :Signature,         :Type => Array.of(Name)
            field   :EF,                :Type => Array.of(Name), :Version => "1.6"
            field   :P,                 :Type => Boolean, :Default => false, :Version => "1.6"

            def initialize(hash = {}, parser = nil)
                set_indirect(false)

                super(hash, parser)
            end
        end
    end

end
