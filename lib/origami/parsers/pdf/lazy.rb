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


require 'origami/parsers/pdf'

module Origami

    class PDF

        #
        # Create a new PDF lazy Parser.
        #
        class LazyParser < Parser
            def parse(stream)
                super

                pdf = parse_initialize
                revisions = []

                # Locate the last xref offset at the end of the file.
                xref_offset = locate_last_xref_offset

                while xref_offset and xref_offset != 0

                    # Create a new revision based on the xref section offset.
                    revision = parse_revision(pdf, xref_offset)

                    # Locate the previous xref section.
                    if revision.xrefstm? and revision.xrefstm[:Prev].is_a?(Integer)
                        xref_offset = revision.xrefstm[:Prev].to_i
                    elsif revision.trailer[:Prev].is_a?(Integer)
                        xref_offset = revision.trailer[:Prev].to_i
                    else
                        xref_offset = nil
                    end

                    # Prepend the revision.
                    revisions.unshift(revision)
                end

                pdf.revisions.clear
                revisions.each do |rev|
                    pdf.revisions.push(rev)
                    pdf.insert(rev.xrefstm) if rev.xrefstm?
                end

                parse_finalize(pdf)

                pdf
            end

            private

            #
            # The document is scanned starting from the end, by locating the last startxref token.
            #
            def locate_last_xref_offset
                # Set the scanner position at the end.
                @data.terminate

                # Locate the startxref token.
                until @data.match?(/#{Trailer::XREF_TOKEN}/)
                    raise ParsingError, "No xref token found" if @data.pos == 0
                    @data.pos -= 1
                end

                # Extract the offset of the last xref section.
                trailer = Trailer.parse(@data, self)
                raise ParsingError, "Cannot locate xref section" if trailer.startxref.zero?

                trailer.startxref
            end

            # 
            # In the LazyParser, the revisions are parsed by jumping through the cross-references (table or streams).
            #
            def parse_revision(pdf, offset)
                raise ParsingError, "Invalid xref offset" unless offset.between?(0, @data.string.size - 1)

                @data.pos = offset

                # Create a new revision.
                revision = PDF::Revision.new(pdf)

                # Regular xref section.
                if @data.match?(/#{XRef::Section::TOKEN}/)
                    parse_revision_from_xreftable(revision)

                # The xrefs are stored in a stream.
                else
                    parse_revision_from_xrefstm(revision)
                end

                revision
            end

            #
            # Assume the current pointer is at the xreftable of the revision.
            # We are expecting:
            #   - a regular xref table, starting with xref
            #   - a revision trailer
            #
            # The trailer may hold a XRefStm entry in case of hybrid references.
            #
            def parse_revision_from_xreftable(revision)
                xreftable = parse_xreftable
                raise ParsingError, "Cannot parse xref section" if xreftable.nil?

                revision.xreftable = xreftable
                revision.trailer = parse_trailer

                # Handle hybrid cross-references.
                if revision.trailer[:XRefStm].is_a?(Integer)
                    begin
                        offset = revision.trailer[:XRefStm].to_i
                        xrefstm = parse_object(offset)

                        if xrefstm.is_a?(XRefStream)
                            revision.xrefstm = xrefstm
                        else
                            warn "Invalid xref stream at offset #{offset}"
                        end

                    rescue
                        warn "Cannot parse xref stream at offset #{offset}"
                    end
                end
            end

            #
            # Assume the current pointer is at the xref stream of the revision.
            #
            # The XRefStream should normally be at the end of the revision.
            # We scan after the object for a trailer token.
            # 
            # The revision is allowed not to have a trailer, and the stream
            # dictionary will be used as the trailer dictionary in that case.
            #
            def parse_revision_from_xrefstm(revision)
                xrefstm = parse_object
                raise ParsingError, "Invalid xref stream" unless xrefstm.is_a?(XRefStream)

                revision.xrefstm = xrefstm

                # Search for the trailer.
                if @data.skip_until Regexp.union(Trailer::XREF_TOKEN, *Trailer::TOKENS)
                    @data.pos -= @data.matched_size

                    revision.trailer = parse_trailer
                else
                    warn "No trailer found."
                    revision.trailer = Trailer.new
                end
            end
        end
    end

end
