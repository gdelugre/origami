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

require 'origami/parser'

module Origami

    class PDF
        class Parser < Origami::Parser
            def initialize(params = {})
                options =
                {
                    decrypt: true,                # Attempt to decrypt to document if encrypted (recommended).
                    password: '',                 # Default password being tried when opening a protected document.
                    prompt_password: lambda do    # Callback procedure to prompt password when document is encrypted.
                        require 'io/console'
                        STDERR.print "Password: "
                        STDIN.noecho(&:gets).chomp
                    end,
                    force: false                  # Force PDF header detection
                }.update(params)

                super(options)
            end

            private

            def parse_initialize #:nodoc:
                if @options[:force] == true
                    @data.skip_until(/%PDF-/).nil?
                    @data.pos = @data.pos - 5
                end

                pdf = PDF.new(self)

                info "...Reading header..."
                begin
                    pdf.header = PDF::Header.parse(@data)
                    @options[:callback].call(pdf.header)
                rescue InvalidHeaderError
                    raise unless @options[:ignore_errors]
                    warn "PDF header is invalid, ignoring..."
                end

                pdf
            end

            def parse_finalize(pdf) #:nodoc:
                cast_trailer_objects(pdf)

                warn "This file has been linearized." if pdf.linearized?

                propagate_types(pdf) if Origami::OPTIONS[:enable_type_propagation]

                #
                # Decrypt encrypted file contents
                #
                if pdf.encrypted?
                    warn "This document contains encrypted data!"

                    decrypt_document(pdf) if @options[:decrypt]
                end

                warn "This document has been signed!" if pdf.signed?

                pdf
            end

            def cast_trailer_objects(pdf) #:nodoc:
                trailer = pdf.trailer

                if trailer[:Root].is_a?(Reference)
                    pdf.cast_object(trailer[:Root], Catalog)
                end

                if trailer[:Info].is_a?(Reference)
                    pdf.cast_object(trailer[:Info], Metadata)
                end

                if trailer[:Encrypt].is_a?(Reference)
                    pdf.cast_object(trailer[:Encrypt], Encryption::Standard::Dictionary)
                end
            end

            def decrypt_document(pdf) #:nodoc:
                passwd = @options[:password]
                begin
                    pdf.decrypt(passwd)
                rescue EncryptionInvalidPasswordError
                    if passwd.empty?
                        passwd = @options[:prompt_password].call
                        retry unless passwd.empty?
                    end

                    raise
                end
            end
        end
    end

end
