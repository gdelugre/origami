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
        # Create a new PDF linear Parser.
        #
        class LinearParser < Parser
            def parse(stream)
                super
            
                pdf = parse_initialize

                #
                # Parse each revision
                #
                revision = 0
                until @data.eos? do
                    begin
                        pdf.add_new_revision unless revision.zero?

                        parse_revision(pdf, revision)
                        revision = revision + 1

                    rescue
                        error "Cannot read : " + (@data.peek(10) + "...").inspect
                        error "Stopped on exception : " + $!.message
                        STDERR.puts $!.backtrace.join($/)

                        break
                    end
                end

                pdf.loaded!

                parse_finalize(pdf)
            end

            private

            def parse_revision(pdf, revision_no)
                revision = pdf.revisions[revision_no]

                info "...Parsing revision #{revision_no + 1}..."
                loop do
                    break if (object = parse_object).nil?
                    pdf.insert(object)
                end

                revision.xreftable = parse_xreftable
                revision.trailer = parse_trailer

                locate_xref_streams(pdf, revision_no)

                revision
            end

            def locate_xref_streams(pdf, revision_no)
                revision = pdf.revisions[revision_no]
                trailer = revision.trailer
                xrefstm = nil

                # Try to match the location of the last startxref / XRefStm with an XRefStream.
                if trailer.startxref != 0
                    xrefstm = pdf.get_object_by_offset(trailer.startxref)
                elsif trailer.key?(:XRefStm)
                    xrefstm = pdf.get_object_by_offset(trailer[:XRefStm])
                end

                if xrefstm.is_a?(XRefStream)
                    warn "Found a XRefStream for revision #{revision_no + 1} at #{xrefstm.reference}"
                    revision.xrefstm = xrefstm

                    if xrefstm.key?(:Prev)
                        locate_prev_xref_streams(pdf, revision_no, xrefstm)
                    end
                end
            end

            def locate_prev_xref_streams(pdf, revision_no, xrefstm)
                return unless revision_no > 0 and xrefstm.Prev.is_a?(Integer)

                prev_revision = pdf.revisions[revision_no - 1]
                prev_offset = xrefstm.Prev.to_i
                prev_xrefstm = pdf.get_object_by_offset(prev_offset)

                if prev_xrefstm.is_a?(XRefStream)
                    warn "Found a previous XRefStream for revision #{revision_no} at #{prev_xrefstm.reference}"
                    prev_revision.xrefstm = prev_xrefstm

                    if prev_xrefstm.key?(:Prev)
                        locate_prev_xref_streams(pdf, revision_no - 1, prev_xrefstm)
                    end
                end
            end
        end
    end

end
