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
        # Decrypts the current document.
        # _passwd_:: The password to decrypt the document.
        #
        def decrypt(passwd = "")
            raise EncryptionError, "PDF is not encrypted" unless self.encrypted?

            # Turn the encryption dictionary into a standard encryption dictionary.
            handler = trailer_key(:Encrypt)
            handler = self.cast_object(handler.reference, Encryption::Standard::Dictionary)

            unless handler.Filter == :Standard
                raise EncryptionNotSupportedError, "Unknown security handler : '#{handler.Filter}'"
            end

            doc_id = trailer_key(:ID)
            unless doc_id.is_a?(Array)
                raise EncryptionError, "Document ID was not found or is invalid" unless handler.V.to_i == 5
            else
                doc_id = doc_id.first
            end

            encryption_key = handler.derive_encryption_key(passwd, doc_id)

            self.extend(Encryption::EncryptedDocument)
            self.encryption_handler = handler
            self.encryption_key = encryption_key

            decrypt_objects

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
                :cipher => 'aes',            # :RC4 or :AES
                :key_size => 128,            # Key size in bits
                :hardened => false,          # Use newer password validation (since Reader X)
                :encrypt_metadata => true,   # Metadata shall be encrypted?
                :permissions => Encryption::Standard::Permissions::ALL    # Document permissions
            }.update(options)

            # Get the cryptographic parameters.
            version, revision = crypto_revision_from_options(params)

            # Create the security handler.
            handler, encryption_key = create_security_handler(version, revision, params)

            # Turn this document into an EncryptedDocument instance.
            self.extend(Encryption::EncryptedDocument)
            self.encryption_handler = handler
            self.encryption_key = encryption_key

            self
        end

        private

        #
        # Installs the standard security dictionary, marking the document as being encrypted.
        # Returns the handler and the encryption key used for protecting contents.
        #
        def create_security_handler(version, revision, params)

            # Ensure the document has an ID.
            doc_id = (trailer_key(:ID) || generate_id).first

            # Create the standard encryption dictionary.
            handler = Encryption::Standard::Dictionary.new
            handler.Filter = :Standard
            handler.V = version
            handler.R = revision
            handler.Length = params[:key_size]
            handler.P = -1 # params[:Permissions]

            # Build the crypt filter dictionary.
            if revision >= 4
                handler.EncryptMetadata = params[:encrypt_metadata]
                handler.CF = Dictionary.new
                crypt_filter = Encryption::CryptFilterDictionary.new
                crypt_filter.AuthEvent = :DocOpen

                if revision == 4
                    crypt_filter.CFM = :AESV2
                else
                    crypt_filter.CFM = :AESV3
                end

                crypt_filter.Length = params[:key_size] >> 3

                handler.CF[:StdCF] = crypt_filter
                handler.StmF = handler.StrF = :StdCF
            end

            user_passwd, owner_passwd = params[:user_passwd], params[:owner_passwd]

            # Setup keys.
            handler.set_passwords(owner_passwd, user_passwd, doc_id)
            encryption_key = handler.compute_user_encryption_key(user_passwd, doc_id)

            # Install the encryption dictionary to the document.
            self.trailer.Encrypt = self << handler

            [ handler, encryption_key ]
        end

        #
        # Converts the parameters passed to PDF#encrypt.
        # Returns [ version, revision, crypt_filters ]
        #
        def crypto_revision_from_options(params)
            case params[:cipher].upcase
            when 'RC4'
                crypto_revision_from_rc4_key(params[:key_size])
            when 'AES'
                crypto_revision_from_aes_key(params[:key_size], params[:hardened])
            else
                raise EncryptionNotSupportedError, "Cipher not supported : #{params[:cipher]}"
            end
        end

        #
        # Compute the required standard security handler version based on the RC4 key size.
        # _key_size_:: Key size in bits.
        # Returns [ version, revision ].
        #
        def crypto_revision_from_rc4_key(key_size)
            raise EncryptionError, "Invalid RC4 key length" unless key_size.between?(40, 128) and key_size % 8 == 0

            if key_size > 40
                version = 2
                revision = 3
            else
                version = 1
                revision = 2
            end

            [ version, revision ]
        end

        #
        # Compute the required standard security handler version based on the AES key size.
        # _key_size_:: Key size in bits.
        # _hardened_:: Use the extension level 8 hardened derivation algorithm.
        # Returns [ version, revision ].
        #
        def crypto_revision_from_aes_key(key_size, hardened)
            if key_size == 128
                version = revision = 4
            elsif key_size == 256
                version = 5
                if hardened
                    revision = 6
                else
                    revision = 5
                end
            else
                raise EncryptionError, "Invalid AES key length (Only 128 and 256 bits keys are supported)"
            end

            [ version, revision ]
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
            SecureRandom.random_bytes(n)
        end

        module EncryptedDocument
            attr_accessor :encryption_key
            attr_accessor :encryption_handler

            # Get the encryption cipher from the crypt filter name.
            def encryption_cipher(name)
                @encryption_handler.encryption_cipher(name)
            end

            # Get the default string encryption cipher.
            def string_encryption_cipher
                @encryption_handler.string_encryption_cipher
            end

            # Get the default stream encryption cipher.
            def stream_encryption_cipher
                @encryption_handler.stream_encryption_cipher
            end

            private

            #
            # For each object subject to encryption, convert it to an EncryptedObject and decrypt it if necessary.
            #
            def decrypt_objects
                each_encryptable_object do |object|
                    case object
                    when String
                        object.extend(EncryptedString) unless object.is_a?(EncryptedString)
                        object.decrypt!

                    when Stream
                        object.extend(EncryptedStream) unless object.is_a?(EncryptedStream)
                    end
                end
            end

            #
            # For each object subject to encryption, convert it to an EncryptedObject and mark it as not encrypted yet.
            #
            def encrypt_objects
                each_encryptable_object do |object|
                    case object
                    when String
                        unless object.is_a?(EncryptedString)
                            object.extend(EncryptedString)
                            object.decrypted = true
                        end

                    when Stream
                        unless object.is_a?(EncryptedStream)
                            object.extend(EncryptedStream)
                            object.decrypted = true
                        end
                    end
                end
            end

            #
            # Iterates over each encryptable objects in the document.
            #
            def each_encryptable_object(&b)

                # Metadata may not be encrypted depending on the security handler configuration.
                encrypt_metadata = (@encryption_handler.EncryptMetadata != false)
                metadata = self.Catalog.Metadata

                self.each_object(recursive: true)
                    .lazy
                    .select { |object|
                        case object
                        when Stream
                            not object.is_a?(XRefStream) or (encrypt_metadata and object.equal?(metadata))
                        when String
                            not object.parent.equal?(@encryption_handler)
                        end
                    }
                    .each(&b)
            end

            def physicalize(options = {})
                encrypt_objects

                super

                # remove encrypt dictionary if requested
                if options[:decrypt]
                    delete_object(self.trailer[:Encrypt])
                    self.trailer[:Encrypt] = nil
                end

                self
            end

            def build_object(object, revision, options)
                if object.is_a?(EncryptedObject) and options[:decrypt]
                    object.pre_build
                    object.decrypt!
                    object.decrypted = false # makes it believe no encryption pass is required
                    object.post_build

                    return
                end

                super
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

                    key_len = [k.length, 16].min
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

                cipher = get_encryption_cipher
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

                cipher = get_encryption_cipher
                key = compute_object_key(cipher)

                self.encoded_data = cipher.decrypt(key, @encoded_data)
                @decrypted = true

                self
            end

            private

            #
            # Get the stream encryption cipher.
            # The cipher used may depend on the presence of a Crypt filter.
            #
            def get_encryption_cipher
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

                cipher
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
        # Class wrapper for the RC4 algorithm.
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
                @key = key
            end

            #
            # Encrypt/decrypt data with the RC4 encryption algorithm
            #
            def cipher(data)
                return '' if data.empty?

                rc4 = OpenSSL::Cipher::RC4.new.encrypt
                rc4.key_len = @key.length
                rc4.key = @key

                rc4.update(data) + rc4.final
            end

            alias encrypt cipher
            alias decrypt cipher
        end

        #
        # Class wrapper for AES mode CBC.
        #
        class AES
            BLOCKSIZE = 16

            attr_writer :iv

            def AES.encrypt(key, iv, data)
                AES.new(key, iv).encrypt(data)
            end

            def AES.decrypt(key, data)
                AES.new(key, nil).decrypt(data)
            end

            def initialize(key, iv, use_padding = true)
                unless [16, 24, 32].include?(key.size)
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

                aes = OpenSSL::Cipher.new("aes-#{@key.length << 3}-cbc").encrypt
                aes.iv = @iv
                aes.key = @key
                aes.padding = 0

                @iv + aes.update(data) + aes.final
            end

            def decrypt(data)
                unless data.size % BLOCKSIZE == 0
                    raise EncryptionError, "Data must be 16-bytes padded (data size = #{data.size} bytes)"
                end

                @iv = data.slice!(0, BLOCKSIZE)

                aes = OpenSSL::Cipher.new("aes-#{@key.length << 3}-cbc").decrypt
                aes.iv = @iv
                aes.key = @key
                aes.padding = 0

                plain = (aes.update(data) + aes.final).unpack("C*")

                if @use_padding
                    padlen = plain[-1]
                    unless padlen.between?(1, 16)
                        raise EncryptionError, "Incorrect padding length : #{padlen}"
                    end

                    padlen.times do
                        pad = plain.pop
                        raise EncryptionError, "Incorrect padding byte : 0x#{pad.to_s 16}" if pad != padlen
                    end
                end

                plain.pack("C*")
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

            #
            # Returns the default string encryption cipher.
            #
            def string_encryption_cipher
                encryption_cipher(self.StrF || :Identity)
            end

            #
            # Returns the default stream encryption cipher.
            #
            def stream_encryption_cipher
                encryption_cipher(self.StmF || :Identity)
            end

            #
            # Returns the encryption cipher corresponding to a crypt filter name.
            #
            def encryption_cipher(name)
                case self.V.to_i
                when 1, 2
                    Encryption::RC4
                when 4, 5
                    return Encryption::Identity if name == :Identity

                    select_cipher_by_name(name)
                else
                    raise EncryptionNotSupportedError, "Unsupported encryption version: #{handler.V}"
                end
            end

            private

            #
            # Returns the cipher associated with a crypt filter name.
            #
            def select_cipher_by_name(name)
                raise EncryptionError, "Broken CF entry" unless self.CF.is_a?(Dictionary)

                self.CF.select { |key, dict| key == name and dict.is_a?(Dictionary) }
                       .map { |_, dict| cipher_from_crypt_filter_method(dict[:CFM] || :None) }
                       .first
            end

            #
            # Converts a crypt filter method identifier to its cipher class.
            #
            def cipher_from_crypt_filter_method(name)
                case name.to_sym
                when :None then Encryption::Identity
                when :V2 then Encryption::RC4
                when :AESV2 then Encryption::AES
                when :AESV3
                    raise EncryptionNotSupportedError, "AESV3 requires a version 5 handler" if self.V.to_i != 5
                    Encryption::AES
                else
                     raise EncryptionNotSupportedError, "Unsupported crypt filter method: #{name}"
                end
            end
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
                        [ '1.7', 8 ]
                    else
                        super
                    end
                end

                #
                # Checks the given password and derives the document encryption key.
                # Raises EncryptionInvalidPasswordError on invalid password.
                #
                def derive_encryption_key(passwd, doc_id)
                    if is_user_password?(passwd, doc_id)
                        compute_user_encryption_key(passwd, doc_id)
                    elsif is_owner_password?(passwd, doc_id)
                        if self.V.to_i < 5
                            user_passwd = retrieve_user_password(passwd)
                            compute_user_encryption_key(user_passwd, doc_id)
                        else
                            compute_owner_encryption_key(passwd)
                        end
                    else
                        raise EncryptionInvalidPasswordError
                    end
                end

                #
                # Computes the key that will be used to encrypt/decrypt the document contents with user password.
                # Called at all revisions.
                #
                def compute_user_encryption_key(user_password, file_id)
                    return compute_legacy_user_encryption_key(user_password, file_id) if self.R < 5

                    passwd = password_to_utf8(user_password)

                    uks = self.U[40, 8]

                    if self.R == 5
                        ukey = Digest::SHA256.digest(passwd + uks)
                    else
                        ukey = compute_hardened_hash(passwd, uks)
                    end

                    iv = ::Array.new(AES::BLOCKSIZE, 0).pack("C*")
                    AES.new(ukey, nil, false).decrypt(iv + self.UE.value)
                end

                #
                # Computes the key that will be used to encrypt/decrypt the document contents.
                # Only for Revision 4 and less.
                #
                def compute_legacy_user_encryption_key(user_password, file_id)
                    padded = pad_password(user_password)
                    padded.force_encoding('binary')

                    padded << self.O
                    padded << [ self.P ].pack("i")

                    padded << file_id

                    encrypt_metadata = self.EncryptMetadata != false
                    padded << [ -1 ].pack("i") if self.R >= 4 and not encrypt_metadata

                    key = Digest::MD5.digest(padded)

                    50.times { key = Digest::MD5.digest(key[0, self.Length / 8]) } if self.R >= 3

                    truncate_key(key)
                end

                #
                # Computes the key that will be used to encrypt/decrypt the document contents with owner password.
                # Revision 5 and above.
                #
                def compute_owner_encryption_key(owner_password)
                    return if self.R < 5

                    passwd = password_to_utf8(owner_password)
                    oks = self.O[40, 8]

                    if self.R == 5
                        okey = Digest::SHA256.digest(passwd + oks + self.U)
                    else
                        okey = compute_hardened_hash(passwd, oks, self.U)
                    end

                    iv = ::Array.new(AES::BLOCKSIZE, 0).pack("C*")
                    AES.new(okey, nil, false).decrypt(iv + self.OE.value)
                end

                #
                # Set up document passwords.
                #
                def set_passwords(owner_password, user_password, salt = nil)
                    return set_legacy_passwords(owner_password, user_password, salt) if self.R < 5

                    upass = password_to_utf8(user_password)
                    opass = password_to_utf8(owner_password)

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

                #
                # Set up document passwords.
                # Only for Revision 4 and less.
                #
                def set_legacy_passwords(owner_password, user_password, salt)
                    owner_key = compute_owner_key(owner_password)
                    upadded = pad_password(user_password)

                    owner_key_hash = RC4.encrypt(owner_key, upadded)
                    19.times { |i| owner_key_hash = RC4.encrypt(xor(owner_key, i + 1), owner_key_hash) } if self.R >= 3

                    self.O = owner_key_hash
                    self.U = compute_user_password_hash(user_password, salt)
                end

                #
                # Checks user password.
                # For version 2, 3 and 4, _salt_ is the document ID.
                # For version 5 and 6, _salt_ is the User Key Salt.
                #
                def is_user_password?(pass, salt)

                    if self.R == 2
                        compute_user_password_hash(pass, salt) == self.U
                    elsif self.R == 3 or self.R == 4
                        compute_user_password_hash(pass, salt)[0, 16] == self.U[0, 16]
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
                def retrieve_user_password(owner_password)

                    key = compute_owner_key(owner_password)

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
                def compute_owner_key(owner_password) #:nodoc:

                    opadded = pad_password(owner_password)

                    owner_key = Digest::MD5.digest(opadded)
                    50.times { owner_key = Digest::MD5.digest(owner_key) } if self.R >= 3

                    truncate_key(owner_key)
                end

                #
                # Compute the value of the U field.
                # Cannot be used with revision 5.
                #
                def compute_user_password_hash(user_password, salt) #:nodoc:

                    if self.R == 2
                        key = compute_user_encryption_key(user_password, salt)
                        user_key = RC4.encrypt(key, PADDING)
                    elsif self.R == 3 or self.R == 4
                        key = compute_user_encryption_key(user_password, salt)

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

                        aes = OpenSSL::Cipher.new("aes-128-cbc").encrypt
                        aes.iv = iv
                        aes.key = key
                        aes.padding = 0

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

                #
                # Some revision handlers require different key sizes.
                # Revision 2 uses 40-bit keys.
                # Revisions 3 and higher rely on the Length field for the key size.
                #
                def truncate_key(key)
                    if self.R == 2
                        key[0, 5]
                    elsif self.R >= 3
                        key[0, self.Length / 8]
                    end
                end

                def xor(str, byte) #:nodoc:
                    str.bytes.map!{|b| b ^ byte }.pack("C*")
                end

                def pad_password(password) #:nodoc:
                    password[0, 32].ljust(32, PADDING)
                end

                def password_to_utf8(passwd) #:nodoc:
                    LiteralString.new(passwd).to_utf8[0, 127]
                end
            end
        end
    end

end
