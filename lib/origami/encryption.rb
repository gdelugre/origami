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

begin
    require 'openssl' if Origami::OPTIONS[:use_openssl]
rescue LoadError
    Origami::OPTIONS[:use_openssl] = false
end

require 'securerandom'
require 'digest/md5'
require 'digest/sha2'

module Origami

    class EncryptionError < Error #:nodoc:
    end

    class EncryptionInvalidPasswordError < EncryptionError #:nodoc:
    end

    class EncryptionNotSupportedError < EncryptionError #:nodoc:
    end

    class PDF

        #
        # Returns whether the PDF file is encrypted.
        #
        def encrypted?
            trailer_key? :Encrypt
        end

        #
        # Decrypts the current document (only RC4 40..128 bits).
        # _passwd_:: The password to decrypt the document.
        #
        def decrypt(passwd = "")
            raise EncryptionError, "PDF is not encrypted" unless self.encrypted?

            encrypt_dict = trailer_key(:Encrypt)
            handler = Encryption::Standard::Dictionary.new(encrypt_dict.dup)

            unless handler.Filter == :Standard
                raise EncryptionNotSupportedError, "Unknown security handler : '#{handler.Filter}'"
            end

            crypt_filters = {
                Identity: Encryption::Identity
            }

            case handler.V.to_i
            when 1,2
                crypt_filters = Hash.new(Encryption::RC4)
                string_filter = stream_filter = nil
            when 4,5
                crypt_filters = {
                    Identity: Encryption::Identity
                }

                if handler[:CF].is_a?(Dictionary)
                    handler[:CF].each_pair do |name, cf|
                        next unless cf.is_a?(Dictionary)

                        crypt_filters[name.value] =
                            if cf[:CFM] == :V2 then Encryption::RC4
                            elsif cf[:CFM] == :AESV2 then Encryption::AES
                            elsif cf[:CFM] == :None then Encryption::Identity
                            elsif cf[:CFM] == :AESV3 and handler.V.to_i == 5 then Encryption::AES
                            else
                                raise EncryptionNotSupportedError, "Unsupported encryption version : #{handler.V}"
                            end
                    end
                end

                string_filter = handler.StrF.is_a?(Name) ? handler.StrF.value : :Identity
                stream_filter = handler.StmF.is_a?(Name) ? handler.StmF.value : :Identity

                unless crypt_filters.key?(string_filter)
                    raise EncryptionError, "Invalid StrF value in encryption dictionary"
                end

                unless crypt_filters.key?(stream_filter)
                    raise EncryptionError, "Invalid StmF value in encryption dictionary"
                end
            else
                raise EncryptionNotSupportedError, "Unsupported encryption version : #{handler.V}"
            end

            doc_id = trailer_key(:ID)
            unless doc_id.is_a?(Array)
                raise EncryptionError, "Document ID was not found or is invalid" unless handler.V.to_i == 5
            else
                doc_id = doc_id.first
            end

            if handler.is_user_password?(passwd, doc_id)
                encryption_key = handler.compute_user_encryption_key(passwd, doc_id)
            elsif handler.is_owner_password?(passwd, doc_id)
                if handler.V.to_i < 5
                    user_passwd = handler.retrieve_user_password(passwd)
                    encryption_key = handler.compute_user_encryption_key(user_passwd, doc_id)
                else
                    encryption_key = handler.compute_owner_encryption_key(passwd)
                end
            else
                raise EncryptionInvalidPasswordError
            end

            encrypt_metadata = (handler.EncryptMetadata != false)

            self.extend(Encryption::EncryptedDocument)
            self.encryption_handler = handler
            self.crypt_filters = crypt_filters
            self.encryption_key = encryption_key
            self.stm_filter, self.str_filter = stream_filter, string_filter

            #
            # Should be fixed to exclude only the active XRefStream
            #
            metadata = self.Catalog.Metadata

            self.indirect_objects.each do |indobj|
                encrypted_objects = []
                case indobj
                when String,Stream then encrypted_objects << indobj
                when Dictionary,Array then encrypted_objects |= indobj.strings_cache
                end

                encrypted_objects.each do |obj|
                    case obj
                    when String
                        next if obj.equal?(encrypt_dict[:U]) or
                                obj.equal?(encrypt_dict[:O]) or
                                obj.equal?(encrypt_dict[:UE]) or
                                obj.equal?(encrypt_dict[:OE]) or
                                obj.equal?(encrypt_dict[:Perms]) or
                                (obj.parent.is_a?(Signature::DigitalSignature) and
                                 obj.equal?(obj.parent[:Contents]))

                        obj.extend(Encryption::EncryptedString) unless obj.is_a?(Encryption::EncryptedString)
                        obj.decrypt!

                    when Stream
                        next if obj.is_a?(XRefStream) or (not encrypt_metadata and obj.equal?(metadata))

                        obj.extend(Encryption::EncryptedStream) unless obj.is_a?(Encryption::EncryptedStream)
                    end
                end
            end

            self
        end

        #
        # Encrypts the current document with the provided passwords.
        # The document will be encrypted at writing-on-disk time.
        # _userpasswd_:: The user password.
        # _ownerpasswd_:: The owner password.
        # _options_:: A set of options to configure encryption.
        #
        def encrypt(options = {})
            raise EncryptionError, "PDF is already encrypted" if self.encrypted?

            #
            # Default encryption options.
            #
            params =
            {
                :user_passwd => '',
                :owner_passwd => '',
                :cipher => 'rc4',            # :RC4 or :AES
                :key_size => 128,            # Key size in bits
                :hardened => false,          # Use newer password validation (since Reader X)
                :encrypt_metadata => true,   # Metadata shall be encrypted?
                :permissions => Encryption::Standard::Permissions::ALL    # Document permissions
            }.update(options)

            userpasswd, ownerpasswd = params[:user_passwd], params[:owner_passwd]

            case params[:cipher].upcase
            when 'RC4'
                algorithm = Encryption::RC4
                if (40..128) === params[:key_size] and params[:key_size] % 8 == 0
                    if params[:key_size] > 40
                        version = 2
                        revision = 3
                    else
                        version = 1
                        revision = 2
                    end
                else
                    raise EncryptionError, "Invalid RC4 key length"
                end

                crypt_filters = Hash.new(algorithm)
                string_filter = stream_filter = nil

            when 'AES'
                algorithm = Encryption::AES
                if params[:key_size] == 128
                    version = revision = 4
                elsif params[:key_size] == 256
                    version = 5
                    if params[:hardened]
                        revision = 6
                    else
                        revision = 5
                    end
                else
                    raise EncryptionError, "Invalid AES key length (Only 128 and 256 bits keys are supported)"
                end

                crypt_filters = {
                    Identity: Encryption::Identity,
                    StdCF: algorithm
                }
                string_filter = stream_filter = :StdCF

            else
                raise EncryptionNotSupportedError, "Cipher not supported : #{params[:cipher]}"
            end

            doc_id = (trailer_key(:ID) || generate_id).first

            handler = Encryption::Standard::Dictionary.new
            handler.Filter = :Standard #:nodoc:
            handler.V = version
            handler.R = revision
            handler.Length = params[:key_size]
            handler.P = -1 # params[:Permissions]

            if revision >= 4
                handler.EncryptMetadata = params[:encrypt_metadata]
                handler.CF = Dictionary.new
                cryptfilter = Encryption::CryptFilterDictionary.new
                cryptfilter.AuthEvent = :DocOpen

                if revision == 4
                    cryptfilter.CFM = :AESV2
                else
                    cryptfilter.CFM = :AESV3
                end

                cryptfilter.Length = params[:key_size] >> 3

                handler.CF[:StdCF] = cryptfilter
                handler.StmF = handler.StrF = :StdCF
            end

            handler.set_passwords(ownerpasswd, userpasswd, doc_id)
            encryption_key = handler.compute_user_encryption_key(userpasswd, doc_id)

            file_info = get_trailer_info
            file_info[:Encrypt] = self << handler

            self.extend(Encryption::EncryptedDocument)
            self.encryption_handler = handler
            self.encryption_key = encryption_key
            self.crypt_filters = crypt_filters
            self.stm_filter = self.str_filter = :StdCF

            self
        end
    end

    #
    # Module to provide support for encrypting and decrypting PDF documents.
    #
    module Encryption

        #
        # Generates _n_ random bytes from a fast PRNG.
        #
        def self.rand_bytes(n)
            Random.new.bytes(n)
        end

        #
        # Generates _n_ random bytes from a crypto PRNG.
        #
        def self.strong_rand_bytes(n)
            if Origami::OPTIONS[:use_openssl]
                OpenSSL::Random.random_bytes(n)
            else
                SecureRandom.random_bytes(n)
            end
        end

        module EncryptedDocument
            attr_accessor :encryption_key
            attr_accessor :encryption_handler
            attr_accessor :str_filter, :stm_filter
            attr_accessor :crypt_filters

            # Get the encryption cipher from the crypt filter name.
            def encryption_cipher(name)
                @crypt_filters[name]
            end

            # Get the default string encryption cipher.
            def string_encryption_cipher
                encryption_cipher @str_filter
            end

            # Get the default stream encryption cipher.
            def stream_encryption_cipher
                encryption_cipher @stm_filter
            end

            private

            def physicalize(options = {})

                build = -> (obj, revision) do
                    if obj.is_a?(EncryptedObject)
                        if options[:decrypt] == true
                            obj.pre_build
                            obj.decrypt!
                            obj.decrypted = false # makes it believe no encryption pass is required
                            obj.post_build

                            return
                        end
                    end

                    if obj.is_a?(ObjectStream)
                        obj.each do |subobj|
                            build.call(subobj, revision)
                        end
                    end

                    obj.pre_build

                    case obj
                    when String
                        if not obj.equal?(@encryption_handler[:U]) and
                           not obj.equal?(@encryption_handler[:O]) and
                           not obj.equal?(@encryption_handler[:UE]) and
                           not obj.equal?(@encryption_handler[:OE]) and
                           not obj.equal?(@encryption_handler[:Perms]) and
                           not (obj.parent.is_a?(Signature::DigitalSignature) and
                               obj.equal?(obj.parent[:Contents])) and
                           not obj.indirect_parent.parent.is_a?(ObjectStream)

                            unless obj.is_a?(EncryptedString)
                                obj.extend(EncryptedString)
                                obj.decrypted = true
                            end
                        end

                    when Stream
                        return if obj.is_a?(XRefStream)
                        return if obj.equal?(self.Catalog.Metadata) and not @encryption_handler.EncryptMetadata

                        unless obj.is_a?(EncryptedStream)
                            obj.extend(EncryptedStream)
                            obj.decrypted = true
                        end

                    when Dictionary, Array
                        obj.map! do |subobj|
                            if subobj.indirect?
                                if get_object(subobj.reference)
                                    subobj.reference
                                else
                                    ref = add_to_revision(subobj, revision)
                                    build.call(subobj, revision)
                                    ref
                                end
                            else
                                subobj
                            end
                        end

                        obj.each do |subobj|
                            build.call(subobj, revision)
                        end
                    end

                    obj.post_build
                end

                # stack up every root objects
                indirect_objects_by_rev.each do |obj, revision|
                    build.call(obj, revision)
                end

                # remove encrypt dictionary if requested
                if options[:decrypt]
                    delete_object(get_trailer_info[:Encrypt])
                    get_trailer_info[:Encrypt] = nil
                end

                self
            end
        end

        #
        # Module for encrypted PDF objects.
        #
        module EncryptedObject #:nodoc
            attr_accessor :decrypted

            def post_build
                encrypt!

                super
            end

            private

            def compute_object_key(cipher)
                doc = self.document
                raise EncryptionError, "Document is not encrypted" unless doc.is_a?(EncryptedDocument)

                encryption_key = doc.encryption_key

                if doc.encryption_handler.V < 5
                    parent = self.indirect_parent
                    no, gen = parent.no, parent.generation
                    k = encryption_key + [no].pack("I")[0..2] + [gen].pack("I")[0..1]

                    key_len = (k.length > 16) ? 16 : k.length
                    k << "sAlT" if cipher == Encryption::AES

                    Digest::MD5.digest(k)[0, key_len]
                else
                    encryption_key
                end
            end
        end

        #
        # Module for encrypted String.
        #
        module EncryptedString
            include EncryptedObject

            def self.extended(obj)
                obj.decrypted = false
            end

            def encrypt!
                return self unless @decrypted

                cipher = self.document.string_encryption_cipher
                raise EncryptionError, "Cannot find string encryption filter" if cipher.nil?

                key = compute_object_key(cipher)

                encrypted_data =
                    if cipher == RC4 or cipher == Identity
                        cipher.encrypt(key, self.value)
                    else
                        iv = Encryption.rand_bytes(AES::BLOCKSIZE)
                        cipher.encrypt(key, iv, self.value)
                    end

                @decrypted = false

                self.replace(encrypted_data)
                self.freeze

                self
            end

            def decrypt!
                return self if @decrypted

                cipher = self.document.string_encryption_cipher
                raise EncryptionError, "Cannot find string encryption filter" if cipher.nil?

                key = compute_object_key(cipher)

                self.replace(cipher.decrypt(key, self.to_str))
                @decrypted = true

                self
            end
        end

        #
        # Module for encrypted Stream.
        #
        module EncryptedStream
            include EncryptedObject

            def self.extended(obj)
                obj.decrypted = false
            end

            def encrypt!
                return self unless @decrypted

                encode!

                if self.filters.first == :Crypt
                    params = decode_params.first

                    if params.is_a?(Dictionary) and params.Name.is_a?(Name)
                        crypt_filter = params.Name.value
                    else
                        crypt_filter = :Identity
                    end

                    cipher = self.document.encryption_cipher(crypt_filter)
                else
                    cipher = self.document.stream_encryption_cipher
                end
                raise EncryptionError, "Cannot find stream encryption filter" if cipher.nil?

                key = compute_object_key(cipher)

                @encoded_data =
                    if cipher == RC4 or cipher == Identity
                        cipher.encrypt(key, self.encoded_data)
                    else
                        iv = Encryption.rand_bytes(AES::BLOCKSIZE)
                        cipher.encrypt(key, iv, @encoded_data)
                    end

                @decrypted = false

                @encoded_data.freeze
                self.freeze

                self
            end

            def decrypt!
                return self if @decrypted

                if self.filters.first == :Crypt
                    params = decode_params.first

                    if params.is_a?(Dictionary) and params.Name.is_a?(Name)
                        crypt_filter = params.Name.value
                    else
                        crypt_filter = :Identity
                    end

                    cipher = self.document.encryption_cipher(crypt_filter)
                else
                    cipher = self.document.stream_encryption_cipher
                end
                raise EncryptionError, "Cannot find stream encryption filter" if cipher.nil?

                key = compute_object_key(cipher)

                self.encoded_data = cipher.decrypt(key, @encoded_data)
                @decrypted = true

                self
            end
        end

        #
        # Identity transformation.
        #
        module Identity
            def Identity.encrypt(_key, data)
                data
            end

            def Identity.decrypt(_key, data)
                data
            end
        end

        #
        # Pure Ruby implementation of the RC4 symmetric algorithm
        #
        class RC4

            #
            # Encrypts data using the given key
            #
            def RC4.encrypt(key, data)
                RC4.new(key).encrypt(data)
            end

            #
            # Decrypts data using the given key
            #
            def RC4.decrypt(key, data)
                RC4.new(key).decrypt(data)
            end

            #
            # Creates and initialises a new RC4 generator using given key
            #
            def initialize(key)
                if Origami::OPTIONS[:use_openssl]
                    @key = key
                else
                    @state = init(key)
                end
            end

            #
            # Encrypt/decrypt data with the RC4 encryption algorithm
            #
            def cipher(data)
                return "" if data.empty?

                if Origami::OPTIONS[:use_openssl]
                    rc4 = OpenSSL::Cipher::RC4.new.encrypt
                    rc4.key_len = @key.length
                    rc4.key = @key

                    output = rc4.update(data) << rc4.final
                else
                    output = ""
                    i, j = 0, 0
                    data.each_byte do |byte|
                        i = i.succ & 0xFF
                        j = (j + @state[i]) & 0xFF

                        @state[i], @state[j] = @state[j], @state[i]

                        output << (@state[@state[i] + @state[j] & 0xFF] ^ byte).chr
                    end
                end

                output
            end

            alias encrypt cipher
            alias decrypt cipher

            private

            def init(key) #:nodoc:
                state = (0..255).to_a

                j = 0
                256.times do |i|
                    j = ( j + state[i] + key[i % key.size].ord ) & 0xFF
                    state[i], state[j] = state[j], state[i]
                end

                state
            end
        end

        #
        # Pure Ruby implementation of the AES symmetric algorithm.
        # Using mode CBC.
        #
        class AES
            NROWS = 4
            NCOLS = 4
            BLOCKSIZE = NROWS * NCOLS

            ROUNDS =
            {
                16 => 10,
                24 => 12,
                32 => 14
            }

            #
            # Rijndael S-box
            #
            SBOX =
            [
                0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
                0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
                0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
                0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
                0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
                0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
                0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
                0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
                0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
                0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
                0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
                0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
                0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
                0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
                0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
                0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
            ]

            #
            # Inverse of the Rijndael S-box
            #
            RSBOX =
            [
                0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
                0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
                0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
                0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
                0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
                0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
                0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
                0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
                0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
                0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
                0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
                0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
                0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
                0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
                0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
                0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d
            ]

            RCON =
            [
                0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a,
                0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39,
                0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a,
                0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8,
                0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef,
                0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc,
                0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b,
                0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3,
                0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94,
                0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20,
                0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35,
                0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f,
                0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04,
                0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63,
                0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd,
                0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb
            ]

            attr_writer :iv

            def AES.encrypt(key, iv, data)
                AES.new(key, iv).encrypt(data)
            end

            def AES.decrypt(key, data)
                AES.new(key, nil).decrypt(data)
            end

            def initialize(key, iv, use_padding = true)
                unless key.size == 16 or key.size == 24 or key.size == 32
                    raise EncryptionError, "Key must have a length of 128, 192 or 256 bits."
                end

                if not iv.nil? and iv.size != BLOCKSIZE
                    raise EncryptionError, "Initialization vector must have a length of #{BLOCKSIZE} bytes."
                end

                @key = key
                @iv = iv
                @use_padding = use_padding
            end

            def encrypt(data)
                if @iv.nil?
                    raise EncryptionError, "No initialization vector has been set."
                end

                if @use_padding
                    padlen = BLOCKSIZE - (data.size % BLOCKSIZE)
                    data << (padlen.chr * padlen)
                end

                if Origami::OPTIONS[:use_openssl]
                    aes = OpenSSL::Cipher::Cipher.new("aes-#{@key.length << 3}-cbc").encrypt
                    aes.iv = @iv
                    aes.key = @key
                    aes.padding = 0

                    @iv + aes.update(data) + aes.final
                else
                    cipher = []
                    cipherblock = []
                    nblocks = data.size / BLOCKSIZE

                    first_round = true
                    nblocks.times do |n|
                        plainblock = data[n * BLOCKSIZE, BLOCKSIZE].unpack("C*")

                        if first_round
                            BLOCKSIZE.times do |i| plainblock[i] ^= @iv[i].ord end
                        else
                            BLOCKSIZE.times do |i| plainblock[i] ^= cipherblock[i] end
                        end

                        first_round = false
                        cipherblock = aes_encrypt(plainblock)
                        cipher.concat(cipherblock)
                    end

                    @iv + cipher.pack("C*")
                end
            end

            def decrypt(data)
                unless data.size % BLOCKSIZE == 0
                    raise EncryptionError, "Data must be 16-bytes padded (data size = #{data.size} bytes)"
                end

                @iv = data.slice!(0, BLOCKSIZE)

                if Origami::OPTIONS[:use_openssl]
                    aes = OpenSSL::Cipher::Cipher.new("aes-#{@key.length << 3}-cbc").decrypt
                    aes.iv = @iv
                    aes.key = @key
                    aes.padding = 0

                    plain = (aes.update(data) + aes.final).unpack("C*")
                else
                    plain = []
                    plainblock = []
                    prev_cipherblock = []
                    nblocks = data.size / BLOCKSIZE

                    first_round = true
                    nblocks.times do |n|
                        cipherblock = data[n * BLOCKSIZE, BLOCKSIZE].unpack("C*")

                        plainblock = aes_decrypt(cipherblock)

                        if first_round
                            BLOCKSIZE.times do |i| plainblock[i] ^= @iv[i].ord end
                        else
                            BLOCKSIZE.times do |i| plainblock[i] ^= prev_cipherblock[i] end
                        end

                        first_round = false
                        prev_cipherblock = cipherblock
                        plain.concat(plainblock)
                    end
                end

                if @use_padding
                    padlen = plain[-1]
                    unless (1..16) === padlen
                        raise EncryptionError, "Incorrect padding length : #{padlen}"
                    end

                    padlen.times do
                        pad = plain.pop
                        raise EncryptionError, "Incorrect padding byte : 0x#{pad.to_s 16}" if pad != padlen
                    end
                end

                plain.pack("C*")
            end

            private

            def rol(row, n = 1) #:nodoc
                n.times do row.push row.shift end ; row
            end

            def ror(row, n = 1) #:nodoc:
                n.times do row.unshift row.pop end ; row
            end

            def galois_mult(a, b) #:nodoc:
                p = 0

                8.times do
                    p ^= a if b[0] == 1
                    highBit = a[7]
                    a <<= 1
                    a ^= 0x1b if highBit == 1
                    b >>= 1
                end

                p % 256
            end

            def schedule_core(word, iter) #:nodoc:
                rol(word)
                word.map! do |byte| SBOX[byte] end
                word[0] ^= RCON[iter]

                word
            end

            def transpose(m) #:nodoc:
                [
                    m[NROWS * 0, NROWS],
                    m[NROWS * 1, NROWS],
                    m[NROWS * 2, NROWS],
                    m[NROWS * 3, NROWS]
                ].transpose.flatten
            end

            #
            # AES round methods.
            #

            def create_round_key(expanded_key, round = 0) #:nodoc:
                transpose(expanded_key[round * BLOCKSIZE, BLOCKSIZE])
            end

            def add_round_key(roundKey) #:nodoc:
                BLOCKSIZE.times do |i| @state[i] ^= roundKey[i] end
            end

            def sub_bytes #:nodoc:
                BLOCKSIZE.times do |i| @state[i] = SBOX[ @state[i] ] end
            end

            def r_sub_bytes #:nodoc:
                BLOCKSIZE.times do |i| @state[i] = RSBOX[ @state[i] ] end
            end

            def shift_rows #:nodoc:
                NROWS.times do |i|
                    @state[i * NCOLS, NCOLS] = rol(@state[i * NCOLS, NCOLS], i)
                end
            end

            def r_shift_rows #:nodoc:
                NROWS.times do |i|
                    @state[i * NCOLS, NCOLS] = ror(@state[i * NCOLS, NCOLS], i)
                end
            end

            def mix_column_with_field(column, field) #:nodoc:
                p = field

                column[0], column[1], column[2], column[3] =
                    galois_mult(column[0], p[0]) ^
                    galois_mult(column[3], p[1]) ^
                    galois_mult(column[2], p[2]) ^
                    galois_mult(column[1], p[3]),

                    galois_mult(column[1], p[0]) ^
                    galois_mult(column[0], p[1]) ^
                    galois_mult(column[3], p[2]) ^
                    galois_mult(column[2], p[3]),

                    galois_mult(column[2], p[0]) ^
                    galois_mult(column[1], p[1]) ^
                    galois_mult(column[0], p[2]) ^
                    galois_mult(column[3], p[3]),

                    galois_mult(column[3], p[0]) ^
                    galois_mult(column[2], p[1]) ^
                    galois_mult(column[1], p[2]) ^
                    galois_mult(column[0], p[3])
            end

            def mix_column(column) #:nodoc:
                mix_column_with_field(column, [ 2, 1, 1, 3 ])
            end

            def r_mix_column_(column) #:nodoc:
                mix_column_with_field(column, [ 14, 9, 13, 11 ])
            end

            def mix_columns #:nodoc:
                NCOLS.times do |c|
                    column = []
                    NROWS.times do |r| column << @state[c + r * NCOLS] end
                    mix_column(column)
                    NROWS.times do |r| @state[c + r * NCOLS] = column[r] end
                end
            end

            def r_mix_columns #:nodoc:
                NCOLS.times do |c|
                    column = []
                    NROWS.times do |r| column << @state[c + r * NCOLS] end
                    r_mix_column_(column)
                    NROWS.times do |r| @state[c + r * NCOLS] = column[r] end
                end
            end

            def expand_key(key) #:nodoc:
                key = key.unpack("C*")
                size = key.size
                expanded_size = 16 * (ROUNDS[key.size] + 1)
                rcon_iter = 1
                expanded_key = key[0, size]

                while expanded_key.size < expanded_size
                    temp = expanded_key[-4, 4]

                    if expanded_key.size % size == 0
                        schedule_core(temp, rcon_iter)
                        rcon_iter = rcon_iter.succ
                    end

                    temp.map! do |b| SBOX[b] end if size == 32 and expanded_key.size % size == 16

                    temp.each do |b| expanded_key << (expanded_key[-size] ^ b) end
                end

                expanded_key
            end

            def aes_round(round_key) #:nodoc:
                sub_bytes
                #puts "after sub_bytes: #{@state.inspect}"
                shift_rows
                #puts "after shift_rows: #{@state.inspect}"
                mix_columns
                #puts "after mix_columns: #{@state.inspect}"
                add_round_key(round_key)
                #puts "roundKey = #{roundKey.inspect}"
                #puts "after add_round_key: #{@state.inspect}"
            end

            def r_aes_round(round_key) #:nodoc:
                add_round_key(round_key)
                r_mix_columns
                r_shift_rows
                r_sub_bytes
            end

            def aes_encrypt(block) #:nodoc:
                @state = transpose(block)
                expanded_key = expand_key(@key)
                rounds = ROUNDS[@key.size]

                aes_main(expanded_key, rounds)
            end

            def aes_decrypt(block) #:nodoc:
                @state = transpose(block)
                expanded_key = expand_key(@key)
                rounds = ROUNDS[@key.size]

                r_aes_main(expanded_key, rounds)
            end

            def aes_main(expanded_key, rounds) #:nodoc:
                #puts "expandedKey: #{expandedKey.inspect}"
                round_key = create_round_key(expanded_key)
                add_round_key(round_key)

                for i in 1..rounds-1
                    round_key = create_round_key(expanded_key, i)
                    aes_round(round_key)
                end

                round_key = create_round_key(expanded_key, rounds)
                sub_bytes
                shift_rows
                add_round_key(round_key)

                transpose(@state)
            end

            def r_aes_main(expanded_key, rounds) #:nodoc:
                round_key = create_round_key(expanded_key, rounds)
                add_round_key(round_key)
                r_shift_rows
                r_sub_bytes

                (rounds - 1).downto(1) do |i|
                    round_key = create_round_key(expanded_key, i)
                    r_aes_round(round_key)
                end

                round_key = create_round_key(expanded_key)
                add_round_key(round_key)

                transpose(@state)
            end
        end

        #
        # Class representing a crypt filter Dictionary
        #
        class CryptFilterDictionary < Dictionary
            include StandardObject

            field   :Type,          :Type => Name, :Default => :CryptFilter
            field   :CFM,           :Type => Name, :Default => :None
            field   :AuthEvent,     :Type => Name, :Default => :DocOpen
            field   :Length,        :Type => Integer
        end

        #
        # Common class for encryption dictionaries.
        #
        class EncryptionDictionary < Dictionary
            include StandardObject

            field   :Filter,        :Type => Name, :Default => :Standard, :Required => true
            field   :SubFilter,     :Type => Name, :Version => "1.3"
            field   :V,             :Type => Integer, :Default => 0
            field   :Length,        :Type => Integer, :Default => 40, :Version => "1.4"
            field   :CF,            :Type => Dictionary, :Version => "1.5"
            field   :StmF,          :Type => Name, :Default => :Identity, :Version => "1.5"
            field   :StrF,          :Type => Name, :Default => :Identity, :Version => "1.5"
            field   :EFF,           :Type => Name, :Version => "1.6"
        end

        #
        # The standard security handler for PDF encryption.
        #
        module Standard
            PADDING = "\x28\xBF\x4E\x5E\x4E\x75\x8A\x41\x64\x00\x4E\x56\xFF\xFA\x01\x08\x2E\x2E\x00\xB6\xD0\x68\x3E\x80\x2F\x0C\xA9\xFE\x64\x53\x69\x7A".b #:nodoc:

            #
            # Permission constants for encrypted documents.
            #
            module Permissions
                RESERVED = 1 << 6 | 1 << 7 | 0xFFFFF000
                PRINT = 1 << 2 | RESERVED
                MODIFY_CONTENTS = 1 << 3 | RESERVED
                COPY_CONTENTS = 1 << 4 | RESERVED
                MODIFY_ANNOTATIONS = 1 << 5 | RESERVED
                FILLIN_FORMS = 1 << 8 | RESERVED
                EXTRACT_CONTENTS = 1 << 9 | RESERVED
                ASSEMBLE_DOC = 1 << 10 | RESERVED
                HIGH_QUALITY_PRINT = 1 << 11 | RESERVED

                ALL = PRINT | MODIFY_CONTENTS | COPY_CONTENTS |
                      MODIFY_ANNOTATIONS | FILLIN_FORMS | EXTRACT_CONTENTS |
                      ASSEMBLE_DOC | HIGH_QUALITY_PRINT
            end

            #
            # Class defining a standard encryption dictionary.
            #
            class Dictionary < EncryptionDictionary

                field   :R,             :Type => Number, :Required => true
                field   :O,             :Type => String, :Required => true
                field   :U,             :Type => String, :Required => true
                field   :OE,            :Type => String, :Version => '1.7', :ExtensionLevel => 3
                field   :UE,            :Type => String, :Version => '1.7', :ExtensionLevel => 3
                field   :Perms,         :Type => String, :Version => '1.7', :ExtensionLevel => 3
                field   :P,             :Type => Integer, :Default => 0, :Required => true
                field   :EncryptMetadata, :Type => Boolean, :Default => true, :Version => "1.5"

                def version_required #:nodoc:
                    if self.R > 5
                        [ 1.7, 8 ]
                    else
                        super
                    end
                end

                #
                # Computes the key that will be used to encrypt/decrypt the document contents with user password.
                #
                def compute_user_encryption_key(userpassword, fileid)
                    if self.R < 5
                        padded = pad_password(userpassword)
                        padded.force_encoding('binary')

                        padded << self.O
                        padded << [ self.P ].pack("i")

                        padded << fileid

                        encrypt_metadata = self.EncryptMetadata != false
                        padded << [ -1 ].pack("i") if self.R >= 4 and not encrypt_metadata

                        key = Digest::MD5.digest(padded)

                        50.times { key = Digest::MD5.digest(key[0, self.Length / 8]) } if self.R >= 3

                        if self.R == 2
                            key[0, 5]
                        elsif self.R >= 3
                            key[0, self.Length / 8]
                        end
                    else
                        passwd = password_to_utf8(userpassword)

                        uks = self.U[40, 8]

                        if self.R == 5
                            ukey = Digest::SHA256.digest(passwd + uks)
                        else
                            ukey = compute_hardened_hash(passwd, uks)
                        end

                        iv = ::Array.new(AES::BLOCKSIZE, 0).pack("C*")
                        AES.new(ukey, nil, false).decrypt(iv + self.UE.value)
                    end
                end

                #
                # Computes the key that will be used to encrypt/decrypt the document contents with owner password.
                # Revision 5 and above.
                #
                def compute_owner_encryption_key(ownerpassword)
                    if self.R >= 5
                        passwd = password_to_utf8(ownerpassword)

                        oks = self.O[40, 8]

                        if self.R == 5
                            okey = Digest::SHA256.digest(passwd + oks + self.U)
                        else
                            okey = compute_hardened_hash(passwd, oks, self.U)
                        end

                        iv = ::Array.new(AES::BLOCKSIZE, 0).pack("C*")
                        AES.new(okey, nil, false).decrypt(iv + self.OE.value)
                    end
                end

                #
                # Set up document passwords.
                #
                def set_passwords(ownerpassword, userpassword, salt = nil)
                    if self.R < 5
                        key = compute_owner_key(ownerpassword)
                        upadded = pad_password(userpassword)

                        owner_key = RC4.encrypt(key, upadded)
                        19.times { |i| owner_key = RC4.encrypt(xor(key,i+1), owner_key) } if self.R >= 3

                        self.O = owner_key
                        self.U = compute_user_password(userpassword, salt)

                    else
                        upass = password_to_utf8(userpassword)
                        opass = password_to_utf8(ownerpassword)

                        uvs, uks, ovs, oks = ::Array.new(4) { Encryption.rand_bytes(8) }
                        file_key = Encryption.strong_rand_bytes(32)
                        iv = ::Array.new(AES::BLOCKSIZE, 0).pack("C*")

                        if self.R == 5
                            self.U = Digest::SHA256.digest(upass + uvs) + uvs + uks
                            self.O = Digest::SHA256.digest(opass + ovs + self.U) + ovs + oks
                            ukey = Digest::SHA256.digest(upass + uks)
                            okey = Digest::SHA256.digest(opass + oks + self.U)
                        else
                            self.U = compute_hardened_hash(upass, uvs) + uvs + uks
                            self.O = compute_hardened_hash(opass, ovs, self.U) + ovs + oks
                            ukey = compute_hardened_hash(upass, uks)
                            okey = compute_hardened_hash(opass, oks, self.U)
                        end

                        self.UE = AES.new(ukey, iv, false).encrypt(file_key)[iv.size, 32]
                        self.OE = AES.new(okey, iv, false).encrypt(file_key)[iv.size, 32]

                        perms =
                            [ self.P ].pack("V") +                              # 0-3
                            [ -1 ].pack("V") +                                  # 4-7
                            (self.EncryptMetadata == true ? "T" : "F") +        # 8
                            "adb" +                                             # 9-11
                            [ 0 ].pack("V")                                     # 12-15

                        self.Perms = AES.new(file_key, iv, false).encrypt(perms)[iv.size, 16]

                        file_key
                    end
                end

                #
                # Checks user password.
                # For version 2,3 and 4, _salt_ is the document ID.
                # For version 5 and 6, _salt_ is the User Key Salt.
                #
                def is_user_password?(pass, salt)

                    if self.R == 2
                        compute_user_password(pass, salt) == self.U
                    elsif self.R == 3 or self.R == 4
                        compute_user_password(pass, salt)[0, 16] == self.U[0, 16]
                    elsif self.R == 5
                        uvs = self.U[32, 8]
                        Digest::SHA256.digest(password_to_utf8(pass) + uvs) == self.U[0, 32]
                    elsif self.R == 6
                        uvs = self.U[32, 8]
                        compute_hardened_hash(password_to_utf8(pass), uvs) == self.U[0, 32]
                    end
                end

                #
                # Checks owner password.
                # For version 2,3 and 4, _salt_ is the document ID.
                # For version 5, _salt_ is (Owner Key Salt + U)
                #
                def is_owner_password?(pass, salt)

                    if self.R < 5
                        user_password = retrieve_user_password(pass)
                        is_user_password?(user_password, salt)
                    elsif self.R == 5
                        ovs = self.O[32, 8]
                        Digest::SHA256.digest(password_to_utf8(pass) + ovs + self.U) == self.O[0, 32]
                    elsif self.R == 6
                        ovs = self.O[32, 8]
                        compute_hardened_hash(password_to_utf8(pass), ovs, self.U[0,48]) == self.O[0, 32]
                    end
                end

                #
                # Retrieve user password from owner password.
                # Cannot be used with revision 5.
                #
                def retrieve_user_password(ownerpassword)

                    key = compute_owner_key(ownerpassword)

                    if self.R == 2
                        RC4.decrypt(key, self.O)
                    elsif self.R == 3 or self.R == 4
                        user_password = RC4.decrypt(xor(key, 19), self.O)
                        19.times { |i| user_password = RC4.decrypt(xor(key, 18-i), user_password) }

                        user_password
                    end
                end

                private

                #
                # Used to encrypt/decrypt the O field.
                # Rev 2,3,4: O = crypt(user_pass, owner_key).
                # Rev 5: unused.
                #
                def compute_owner_key(ownerpassword) #:nodoc:

                    opadded = pad_password(ownerpassword)

                    hash = Digest::MD5.digest(opadded)
                    50.times { hash = Digest::MD5.digest(hash) } if self.R >= 3

                    if self.R == 2
                        hash[0, 5]
                    elsif self.R >= 3
                        hash[0, self.Length / 8]
                    end
                end

                #
                # Compute the value of the U field.
                # Cannot be used with revision 5.
                #
                def compute_user_password(userpassword, salt) #:nodoc:

                    if self.R == 2
                        key = compute_user_encryption_key(userpassword, salt)
                        user_key = RC4.encrypt(key, PADDING)
                    elsif self.R == 3 or self.R == 4
                        key = compute_user_encryption_key(userpassword, salt)

                        upadded = PADDING + salt
                        hash = Digest::MD5.digest(upadded)

                        user_key = RC4.encrypt(key, hash)

                        19.times { |i| user_key = RC4.encrypt(xor(key,i+1), user_key) }

                        user_key.ljust(32, 0xFF.chr)
                    end
                end

                #
                # Computes hardened hash used in revision 6 (extension level 8).
                #
                def compute_hardened_hash(password, salt, vector = '')
                    block_size = 32
                    input = Digest::SHA256.digest(password + salt + vector) + "\x00" * 32
                    key = input[0, 16]
                    iv = input[16, 16]
                    digest, aes, h, x = nil, nil, nil, nil

                    i = 0
                    while i < 64 or i < x[-1].ord + 32

                        block = input[0, block_size]

                        if Origami::OPTIONS[:use_openssl]
                            aes = OpenSSL::Cipher::Cipher.new("aes-128-cbc").encrypt
                            aes.iv = iv
                            aes.key = key
                            aes.padding = 0
                        else
                            fail "You need OpenSSL support to encrypt/decrypt documents with this method"
                        end

                        64.times do |j|
                            x = ''
                            x += aes.update(password) unless password.empty?
                            x += aes.update(block)
                            x += aes.update(vector) unless vector.empty?

                            if j == 0
                                block_size = 32 + (x.unpack("C16").inject(0) {|a,b| a+b} % 3) * 16
                                digest = Digest::SHA2.new(block_size << 3)
                            end

                            digest.update(x)
                        end

                        h = digest.digest
                        key = h[0, 16]
                        input[0, block_size] = h[0, block_size]
                        iv = h[16, 16]

                        i = i + 1
                    end

                    h[0, 32]
                end

                def xor(str, byte) #:nodoc:
                    str.split(//).map!{|c| (c[0].ord ^ byte).chr }.join
                end

                def pad_password(password) #:nodoc:
                    return PADDING.dup if password.empty? # Fix for Ruby 1.9 bug
                    password[0,32].ljust(32, PADDING)
                end

                def password_to_utf8(passwd) #:nodoc:
                    LiteralString.new(passwd).to_utf8[0, 127]
                end
            end
        end
    end

end
