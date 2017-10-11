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

require 'colorize'
require 'strscan'

module Origami

    class Parser #:nodoc:

        class ParsingError < Error #:nodoc:
        end

        #
        # Do not output debug information.
        #
        VERBOSE_QUIET = 0

        #
        # Output some useful information.
        #
        VERBOSE_INFO = 1

        #
        # Output debug information.
        #
        VERBOSE_DEBUG = 2

        #
        # Output every objects read
        #
        VERBOSE_TRACE = 3

        attr_accessor :options

        def initialize(options = {}) #:nodoc:
            # Type information for indirect objects.
            @deferred_casts = {}

            #Default options values
            @options =
            {
                verbosity: VERBOSE_INFO, # Verbose level.
                ignore_errors: true,     # Try to keep on parsing when errors occur.
                callback: Proc.new {},   # Callback procedure whenever a structure is read.
                logger: STDERR,          # Where to output parser messages.
                colorize_log: true       # Colorize parser output?
            }

            @options.update(options)
            @logger = @options[:logger]
            @data = nil
        end

        def pos
            raise RuntimeError, "Cannot get position, parser has no loaded data." if @data.nil?

            @data.pos
        end

        def pos=(offset)
            raise RuntimeError, "Cannot set position, parser has no loaded data." if @data.nil?

            @data.pos = offset
        end

        def parse(stream)
            data =
            if stream.respond_to? :read
                StringScanner.new(stream.read.force_encoding('binary'))
            elsif stream.is_a? ::String
                @filename = stream
                StringScanner.new(File.binread(@filename))
            elsif stream.is_a? StringScanner
                stream
            else
                raise TypeError
            end

            @data = data
            @data.pos = 0
        end

        def parse_object(pos = @data.pos) #:nodoc:
            @data.pos = pos

            begin
                obj = Object.parse(@data, self)
                return if obj.nil?

                obj = try_object_promotion(obj)
                trace "Read #{obj.type} object, #{obj.reference}"

                @options[:callback].call(obj)
                obj

            rescue UnterminatedObjectError
                error $!.message
                obj = $!.obj

                Object.skip_until_next_obj(@data)
                @options[:callback].call(obj)
                obj

            rescue
                error "Breaking on: #{(@data.peek(10) + "...").inspect} at offset 0x#{@data.pos.to_s(16)}"
                error "Last exception: [#{$!.class}] #{$!.message}"
                if not @options[:ignore_errors]
                    error "Manually fix the file or set :ignore_errors parameter."
                    raise
                end

                debug 'Skipping this indirect object.'
                raise if not Object.skip_until_next_obj(@data)

                retry
            end
        end

        def parse_xreftable(pos = @data.pos) #:nodoc:
            @data.pos = pos

            begin
                info "...Parsing xref table..."
                xreftable = XRef::Section.parse(@data)
                @options[:callback].call(xreftable)

                xreftable

            rescue
                debug "Exception caught while parsing xref table : " + $!.message
                warn "Unable to parse xref table! Xrefs might be stored into an XRef stream."

                @data.pos -= 'trailer'.length unless @data.skip_until(/trailer/).nil?

                nil
            end
        end

        def parse_trailer(pos = @data.pos) #:nodoc:
            @data.pos = pos

            begin
                info "...Parsing trailer..."
                trailer = Trailer.parse(@data, self)

                @options[:callback].call(trailer)
                trailer

            rescue
                debug "Exception caught while parsing trailer : " + $!.message
                warn "Unable to parse trailer!"

                raise
            end
        end

        def defer_type_cast(reference, type) #:nodoc:
            @deferred_casts[reference] = type
        end

        def target_filename
            @filename
        end

        def target_filesize
            @data.string.size if @data
        end

        def target_data
            @data.string.dup if @data
        end

        def error(msg = "") #:nodoc:
            log(VERBOSE_QUIET, 'error', :red, msg)
        end

        def warn(msg = "") #:nodoc:
            log(VERBOSE_INFO, 'warn ', :yellow, msg)
        end

        def info(msg = "") #:nodoc:
            log(VERBOSE_INFO, 'info ', :green, msg)
        end

        def debug(msg = "") #:nodoc:
            log(VERBOSE_DEBUG, 'debug', :magenta, msg)
        end

        def trace(msg = "") #:nodoc:
            log(VERBOSE_TRACE, 'trace', :cyan, msg)
        end

        def self.init_scanner(stream)
            if stream.is_a?(StringScanner)
                stream
            elsif stream.respond_to?(:to_str)
                StringScanner.new(stream.to_str)
            else
                raise TypeError, "Cannot initialize scanner from #{stream.class}"
            end
        end

        private

        #
        # Attempt to promote an object using the deferred casts.
        #
        def try_object_promotion(obj)
            return obj unless Origami::OPTIONS[:enable_type_propagation] and @deferred_casts.key?(obj.reference)

            types = @deferred_casts[obj.reference]
            types = [ types ] unless types.is_a?(::Array)

            # Promote object if a compatible type is found.
            cast_type = types.find {|type| type < obj.class }
            if cast_type
                obj = obj.cast_to(cast_type, self)
            else
                obj
            end
        end

        def log(level, prefix, color, message) #:nodoc:
            return unless @options[:verbosity] >= level

            if @options[:colorize_log]
                @logger.print "[#{prefix}] ".colorize(color)
                @logger.puts message
            else
                @logger.puts "[#{prefix}] #{message}"
            end
        end

        def propagate_types(document)
            info "...Propagating types..."

            current_state = nil
            until current_state == @deferred_casts
                current_state = @deferred_casts.clone

                current_state.each_pair do |ref, type|
                    type = [ type ] unless type.is_a?(::Array)
                    type.each do |hint|
                        break if document.cast_object(ref, hint)
                    end
                end
            end
        end
    end

end
