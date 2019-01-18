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

    class SignatureError < Error #:nodoc:
    end

    class PDF
        #
        # Verify a document signature.
        #   _:trusted_certs_: an array of trusted X509 certificates.
        #   _:use_system_store_: use the system store for certificate authorities.
        #   _:allow_self_signed_: allow self-signed certificates in the verification chain.
        #   _verify_cb_: block called when encountering a certificate that cannot be verified.
        #                Passed argument in the OpenSSL::X509::StoreContext.
        #
        def verify(trusted_certs: [],
                   use_system_store: false,
                   allow_self_signed: false,
                   &verify_cb)

            digsig = self.signature
            digsig = digsig.cast_to(Signature::DigitalSignature) unless digsig.is_a?(Signature::DigitalSignature)

            signature = digsig.signature_data
            chain = digsig.certificate_chain
            subfilter = digsig.SubFilter.value

            store = OpenSSL::X509::Store.new
            store.set_default_paths if use_system_store
            trusted_certs.each { |ca| store.add_cert(ca) }

            store.verify_callback = -> (success, ctx) {
                return true if success

                error = ctx.error
                is_self_signed = (error == OpenSSL::X509::V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT ||
                                  error == OpenSSL::X509::V_ERR_SELF_SIGNED_CERT_IN_CHAIN)

                return true if is_self_signed && allow_self_signed && verify_cb.nil?

                verify_cb.call(ctx) unless verify_cb.nil?
            }

            data = extract_signed_data(digsig)
            Signature.verify(subfilter.to_s, data, signature, store, chain)
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
                 method: Signature::PKCS7_DETACHED,
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
                raise TypeError, "Expected an Array of CA certificates."
            end

            unless annotation.nil? or annotation.is_a?(Annotation::Widget::Signature)
                raise TypeError, "Expected a Annotation::Widget::Signature object."
            end

            #
            # XXX: Currently signing a linearized document will result in a broken document.
            # Delinearize the document first until we find a proper way to handle this case.
            #
            if self.linearized?
                self.delinearize!
            end

            digsig = Signature::DigitalSignature.new.set_indirect(true)

            if annotation.nil?
                annotation = Annotation::Widget::Signature.new
                annotation.Rect = Rectangle[:llx => 0.0, :lly => 0.0, :urx => 0.0, :ury => 0.0]
            end

            annotation.V = digsig
            add_fields(annotation)
            self.Catalog.AcroForm.SigFlags =
                InteractiveForm::SigFlags::SIGNATURES_EXIST | InteractiveForm::SigFlags::APPEND_ONLY

            digsig.Type = :Sig
            digsig.Contents = HexaString.new("\x00" * Signature::required_size(method, certificate, key, ca))
            digsig.Filter = :"Adobe.PPKLite"
            digsig.SubFilter = Name.new(method)
            digsig.ByteRange = [0, 0, 0, 0]
            digsig.Name = issuer

            digsig.Location = HexaString.new(location) if location
            digsig.ContactInfo = HexaString.new(contact) if contact
            digsig.Reason = HexaString.new(reason) if reason

            # PKCS1 signatures require a Cert entry.
            if method == Signature::PKCS1_RSA_SHA1
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

            #
            # Computes and inserts the signature.
            #
            signature = Signature.compute(method, signable_data, certificate, key, ca)
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
                self.Catalog.AcroForm.SigFlags.is_a?(Integer) and
                (self.Catalog.AcroForm.SigFlags & InteractiveForm::SigFlags::SIGNATURES_EXIST != 0)
            rescue InvalidReferenceError
                false
            end
        end

        #
        # Enable the document Usage Rights.
        # _rights_:: list of rights defined in UsageRights::Rights
        #
        def enable_usage_rights(cert, pkey, *rights)

            # Always uses a detached PKCS7 signature for UR.
            method = Signature::PKCS7_DETACHED

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
            #self.Catalog.AcroForm.SigFlags = InteractiveForm::SigFlags::APPEND_ONLY

            digsig.Type = :Sig
            digsig.Contents = HexaString.new("\x00" * Signature.required_size(method, certificate, key, []))
            digsig.Filter = :"Adobe.PPKLite"
            digsig.Name = "ARE Acrobat Product v8.0 P23 0002337"
            digsig.SubFilter = Name.new(method )
            digsig.ByteRange = [0, 0, 0, 0]

            sigref = Signature::Reference.new
            sigref.Type = :SigRef
            sigref.TransformMethod = :UR3
            sigref.Data = self.Catalog

            sigref.TransformParams = UsageRights::TransformParams.new
            sigref.TransformParams.P = true
            sigref.TransformParams.Type = :TransformParams
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

            signature = Signature.compute(method, signable_data, certificate, key, [])
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

        private

        #
        # Verifies the ByteRange field of a digital signature and returned the signed data.
        #
        def extract_signed_data(digsig)
            # Computes the boundaries of the Contents field.
            start_sig = digsig[:Contents].file_offset

            stream = StringScanner.new(self.original_data)
            stream.pos = digsig[:Contents].file_offset
            Object.typeof(stream).parse(stream)
            end_sig = stream.pos
            stream.terminate

            r1, r2 = digsig.ranges
            if r1.begin != 0 or
                r2.end != self.original_data.size or
                r1.end != start_sig or
                r2.begin != end_sig

                raise SignatureError, "Invalid signature byte range"
            end

            self.original_data[r1] + self.original_data[r2]
        end

    end

    class Perms < Dictionary
        include StandardObject

        field   :DocMDP,          :Type => Dictionary
        field   :UR,              :Type => Dictionary
        field   :UR3,             :Type => Dictionary, :Version => "1.6"
    end

    module Signature

        PKCS1_RSA_SHA1  = "adbe.x509.rsa_sha1"
        PKCS7_SHA1      = "adbe.pkcs7.sha1"
        PKCS7_DETACHED  = "adbe.pkcs7.detached"

        #
        # PKCS1 class used for adbe.x509.rsa_sha1.
        #
        class PKCS1
            class PKCS1Error < SignatureError; end

            def initialize(signature)
                @signature_object = decode_pkcs1(signature)
            end

            def verify(certificate, chain, store, data)
                store.verify(certificate, chain) and certificate.public_key.verify(OpenSSL::Digest::SHA1.new, @signature_object.value, data)
            end

            def self.sign(certificate, key, data)
                raise PKCS1Error, "Invalid key for certificate" unless certificate.check_private_key(key)

                self.new encode_pkcs1 key.sign(OpenSSL::Digest::SHA1.new, data)
            end

            def to_der
                @signature_object.to_der
            end

            private

            def decode_pkcs1(data)
                #
                # Extracts the first ASN.1 object from the data and discards the rest.
                # Must be an octet string.
                #
                signature_len = 0
                OpenSSL::ASN1.traverse(data) do |_, offset, hdr_len, len, _, _, tag|
                    raise PKCS1Error, "Invalid PKCS1 object, expected an ASN.1 octet string" unless tag == OpenSSL::ASN1::OCTET_STRING

                    signature_len = offset + hdr_len + len
                    break
                end

                OpenSSL::ASN1.decode(data[0, signature_len])
            end

            def self.encode_pkcs1(data)
                OpenSSL::ASN1::OctetString.new(data).to_der
            end
            private_class_method :encode_pkcs1
        end

        def self.verify(method, data, signature, store, chain)
            case method
            when PKCS7_DETACHED
                pkcs7 = OpenSSL::PKCS7.new(signature)
                raise SignatureError, "Not a PKCS7 detached signature" unless pkcs7.detached?
                pkcs7.verify([], store, data, OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY)

            when PKCS7_SHA1
                pkcs7 = OpenSSL::PKCS7.new(signature)
                pkcs7.verify([], store, nil, OpenSSL::PKCS7::BINARY) and pkcs7.data == Digest::SHA1.digest(data)

            when PKCS1_RSA_SHA1
                raise SignatureError, "Cannot verify RSA signature without a certificate" if chain.empty?
                cert = chain.shift
                pkcs1 = PKCS1.new(signature)
                pkcs1.verify(cert, chain, store, data)

            else
                raise NotImplementedError, "Unsupported signature method #{method.inspect}"
            end
        end

        #
        # Computes the required size in bytes for storing the signature.
        #
        def self.required_size(method, certificate, key, ca)
            self.compute(method, "", certificate, key, ca).size
        end

        #
        # Computes the signature using the specified subfilter method.
        #
        def self.compute(method, data, certificate, key, ca)
            case method
            when PKCS7_DETACHED
                OpenSSL::PKCS7.sign(certificate, key, data, ca, OpenSSL::PKCS7::DETACHED | OpenSSL::PKCS7::BINARY).to_der

            when PKCS7_SHA1
                OpenSSL::PKCS7.sign(certificate, key, Digest::SHA1.digest(data), ca, OpenSSL::PKCS7::BINARY).to_der

            when PKCS1_RSA_SHA1
                PKCS1.sign(certificate, key, data).to_der

            else
                raise NotImplementedError, "Unsupported signature method #{method.inspect}"
            end
        end

        #
        # Class representing a signature which can be embedded in DigitalSignature dictionary.
        # It must be a direct object.
        #
        class Reference < Dictionary
            include StandardObject

            add_type_signature        :Type => :SigRef

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

            add_type_signature        :Filter => :"Adobe.PPKLite"
            add_type_signature        :Filter => :"Adobe.PPKMS"

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

            def to_s(indent: 1, tab: "\t", eol: $/) #:nodoc:

                # Must be deterministic.
                indent, tab, eol = 1, "\t", $/

                content = TOKENS.first + eol

                self.to_a.sort_by{ |key, _| key }.reverse_each do |key, value|
                    content << tab * indent << key.to_s << " "
                    content << (value.is_a?(Dictionary) ? value.to_s(indent: indent + 1) : value.to_s) << eol
                end

                content << tab * (indent - 1) << TOKENS.last

                output(content)
            end

            def ranges
                byte_range = self.ByteRange

                unless byte_range.is_a?(Array) and byte_range.length == 4 and byte_range.all? {|i| i.is_a?(Integer) }
                    raise SignatureError, "Invalid ByteRange field value"
                end

                byte_range.map(&:to_i).each_slice(2).map do |start, length|
                    (start...start + length)
                end
            end

            def signature_data
                raise SignatureError, "Invalid signature data" unless self[:Contents].is_a?(String)

                self[:Contents]
            end

            def certificate_chain
                return [] unless key?(:Cert)

                chain = self.Cert
                unless chain.is_a?(String) or (chain.is_a?(Array) and chain.all?{|cert| cert.is_a?(String)})
                    return SignatureError, "Invalid embedded certificate chain"
                end

                [ chain ].flatten.map! {|str| OpenSSL::X509::Certificate.new(str) }
            end

            def signature_offset #:nodoc:
                indent, tab, eol = 1, "\t", $/
                content = "#{no} #{generation} obj" + eol + TOKENS.first + eol

                self.to_a.sort_by{ |key, _| key }.reverse_each do |key, value|
                    if key == :Contents
                        content << tab * indent + key.to_s + " "

                        return content.size
                    else
                        content << tab * indent + key.to_s << " "
                        content << (value.is_a?(Dictionary) ? value.to_s(indent: indent + 1) : value.to_s) << eol
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
