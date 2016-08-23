=begin

    This file is part of PDF Walker, a graphical PDF file browser
    Copyright (C) 2016	Guillaume Delugré.

    PDF Walker is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    PDF Walker is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with PDF Walker.  If not, see <http://www.gnu.org/licenses/>.

=end

module PDFWalker

    class Walker < Window

        def display_signing_wizard
            SignWizard.new(self, @opened) if @opened
        end

        def display_usage_rights_wizard
            UsageRightsWizard.new(self, @opened) if @opened
        end

        module SignatureDialogs
            private

            def open_private_key_dialog(page)
                dialog = FileChooserDialog.new("Choose a private RSA key",
                            @parent,
                            FileChooser::ACTION_OPEN,
                            nil,
                            [Stock::CANCEL, Dialog::RESPONSE_CANCEL],
                            [Stock::OPEN, Dialog::RESPONSE_ACCEPT])

                filter = FileFilter.new
                filter.add_pattern("*.key")
                filter.add_pattern("*.pem")
                filter.add_pattern("*.der")

                dialog.set_filter(filter)

                if dialog.run == Dialog::RESPONSE_ACCEPT
                    begin
                        @pkey = OpenSSL::PKey::RSA.new(File.binread(dialog.filename))

                        @pkeyfilename.set_text(dialog.filename)
                        set_page_complete(page, true) if @cert
                    rescue
                        @parent.error("Error loading file '#{File.basename(dialog.filename)}'")

                        @pkey = nil
                        @pkeyfilename.text = ""
                        set_page_complete(page, false)
                    ensure
                        @ca = [] # Shall be added to the GUI
                    end
                end

                dialog.destroy
            end

            def open_certificate_dialog(page)
                dialog = FileChooserDialog.new("Choose a x509 certificate",
                            @parent,
                            FileChooser::ACTION_OPEN,
                            nil,
                            [Stock::CANCEL, Dialog::RESPONSE_CANCEL],
                            [Stock::OPEN, Dialog::RESPONSE_ACCEPT])
                filter = FileFilter.new
                filter.add_pattern("*.crt")
                filter.add_pattern("*.cer")
                filter.add_pattern("*.pem")
                filter.add_pattern("*.der")

                dialog.set_filter(filter)

                if dialog.run == Dialog::RESPONSE_ACCEPT
                    begin
                        @cert = OpenSSL::X509::Certificate.new(File.binread(dialog.filename))

                        @certfilename.set_text(dialog.filename)
                        if @pkey then set_page_complete(page, true) end

                    rescue
                        @parent.error("Error loading file '#{File.basename(dialog.filename)}'")

                        @cert = nil
                        @certfilename.text = ""
                        set_page_complete(page, false)
                    ensure
                        @ca = [] # Shall be added to the GUI
                    end
                end

                dialog.destroy
            end

            def open_pkcs12_file_dialog(page)

                dialog = FileChooserDialog.new("Open PKCS12 container",
                            @parent,
                            FileChooser::ACTION_OPEN,
                            nil,
                            [Stock::CANCEL, Dialog::RESPONSE_CANCEL],
                            [Stock::OPEN, Dialog::RESPONSE_ACCEPT])
                filter = FileFilter.new
                filter.add_pattern("*.pfx")
                filter.add_pattern("*.p12")

                dialog.filter = filter

                if dialog.run == Dialog::RESPONSE_ACCEPT
                    begin
                        p12 = OpenSSL::PKCS12::PKCS12.new(File.binread(dialog.filename), method(:prompt_passphrase))

                        raise TypeError, "PKCS12 does not contain a RSA key" unless p12.key.is_a?(OpenSSL::PKey::RSA)
                        raise TypeError, "PKCS12 does not contain a x509 certificate" unless p12.certificate.is_a?(OpenSSL::X509::Certificate)

                        @pkey = p12.key
                        @cert = p12.certificate
                        @ca = p12.ca_certs

                        @p12filename.set_text(dialog.filename)
                        set_page_complete(page, true)
                    rescue
                        @parent.error("Error loading file '#{File.basename(dialog.filename)}'")

                        @pkey, @cert, @ca = nil, nil, []
                        @p12filename.text = ""
                        set_page_complete(page, false)

                    end
                end

                dialog.destroy
            end

            def prompt_passphrase
                dialog = Dialog.new("Enter passphrase",
                            @parent,
                            Dialog::MODAL,
                            [Stock::OK, Dialog::RESPONSE_OK]
                )

                pwd_entry = Entry.new.set_visibility(false).show
                dialog.vbox.pack_start(pwd_entry, true, true, 0)

                pwd = pwd_entry.text if dialog.run == Dialog::RESPONSE_OK

                dialog.destroy
                pwd.to_s
            end
        end

        class UsageRightsWizard < Assistant
            include SignatureDialogs

            def initialize(parent, pdf)
                super()

                @parent = parent
                @pkey, @cert = nil, nil

                create_intro_page
                create_keypair_import_page
                create_rights_selection_page
                create_termination_page

                signal_connect('delete_event') { self.destroy }
                signal_connect('cancel') { self.destroy }
                signal_connect('close') { self.destroy }

                signal_connect('apply') {
                    rights = selected_usage_rights

                    begin
                        pdf.enable_usage_rights(@cert, @pkey, *rights)

                        set_page_title(@lastpage, "Usage Rights have been enabled")
                        @msg_status.text = "Usage Rights have been enabled for the current document.\n You should consider saving it now."

                        @parent.reload
                    rescue
                        @parent.error("#{$!}: #{$!.backtrace.join($/)}")

                        set_page_title(@lastpage, "Usage Rights have not been enabled")
                        @msg_status.text = "An error occured during the signature process."
                    end
                }

                set_modal(true)

                show_all
            end

            private

            def selected_usage_rights
                selected_document_rights +
                selected_annotations_rights +
                selected_form_rights +
                selected_signature_rights +
                selected_file_rights
            end

            def selected_document_rights
                rights = []
                rights << Origami::UsageRights::Rights::DOCUMENT_FULLSAVE if @document_fullsave.active?

                rights
            end

            def selected_annotations_rights
                rights = []
                rights << Origami::UsageRights::Rights::ANNOTS_CREATE if @annots_create.active?
                rights << Origami::UsageRights::Rights::ANNOTS_DELETE if @annots_delete.active?
                rights << Origami::UsageRights::Rights::ANNOTS_MODIFY if @annots_modify.active?
                rights << Origami::UsageRights::Rights::ANNOTS_COPY if @annots_copy.active?
                rights << Origami::UsageRights::Rights::ANNOTS_IMPORT if @annots_import.active?
                rights << Origami::UsageRights::Rights::ANNOTS_EXPORT if @annots_export.active?
                rights << Origami::UsageRights::Rights::ANNOTS_ONLINE if @annots_online.active?
                rights << Origami::UsageRights::Rights::ANNOTS_SUMMARYVIEW if @annots_sumview.active?

                rights
            end

            def selected_form_rights
                rights = []
                rights << Origami::UsageRights::Rights::FORM_FILLIN if @form_fillin.active?
                rights << Origami::UsageRights::Rights::FORM_IMPORT if @form_import.active?
                rights << Origami::UsageRights::Rights::FORM_EXPORT if @form_export.active?
                rights << Origami::UsageRights::Rights::FORM_SUBMITSTANDALONE if @form_submit.active?
                rights << Origami::UsageRights::Rights::FORM_SPAWNTEMPLATE if @form_spawntemplate.active?
                rights << Origami::UsageRights::Rights::FORM_BARCODEPLAINTEXT if @form_barcode.active?
                rights << Origami::UsageRights::Rights::FORM_ONLINE if @form_online.active?

                rights
            end

            def selected_signature_rights
                rights = []
                rights << Origami::UsageRights::Rights::SIGNATURE_MODIFY if @signature_modify.active?

                rights
            end

            def selected_file_rights
                rights = []
                rights << Origami::UsageRights::Rights::EF_CREATE if @ef_create.active?
                rights << Origami::UsageRights::Rights::EF_DELETE if @ef_delete.active?
                rights << Origami::UsageRights::Rights::EF_MODIFY if @ef_modify.active?
                rights << Origami::UsageRights::Rights::EF_IMPORT if @ef_import.active?

                rights
            end

            def create_intro_page
                intro = <<-INTRO.gsub(/^\s+/, '')
                    You are about to enable Usage Rights for the current PDF document.
                    To enable these features, you need to have an Adobe public/private key pair in your possession.

                    Make sure you have adobe.crt and adobe.key located in the current directory.
                INTRO

                vbox = VBox.new(false, 5)
                vbox.set_border_width(5)

                lbl = Label.new(intro).set_justify(Gtk::JUSTIFY_LEFT).set_wrap(true)

                vbox.pack_start(lbl, true, true, 0)

                append_page(vbox)
                set_page_title(vbox, "Usage Rights Wizard")
                set_page_type(vbox, Assistant::PAGE_INTRO)
                set_page_complete(vbox, true)
            end

            def create_keypair_import_page

                labels =
                [
                    [ "Private RSA key:", @pkeyfilename = Entry.new,  pkeychoosebtn = Button.new(Gtk::Stock::OPEN) ],
                    [ "Public certificate:", @certfilename = Entry.new, certchoosebtn = Button.new(Gtk::Stock::OPEN) ]
                ]

                row = 0
                table = Table.new(2, 3)
                labels.each do |lbl, entry, btn|
                    entry.editable = entry.sensitive = false

                    table.attach(Label.new(lbl).set_alignment(1,0), 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    table.attach(entry, 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    table.attach(btn, 2, 3, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)

                    row = row.succ
                end

                pkeychoosebtn.signal_connect('clicked') { open_private_key_dialog(table) }
                certchoosebtn.signal_connect('clicked') { open_certificate_dialog(table) }

                append_page(table)
                set_page_title(table, "Import a public/private key pair")
                set_page_type(table, Assistant::PAGE_CONTENT)
            end

            def create_rights_selection_page
                vbox = VBox.new(false, 5)

                docframe = Frame.new(" Document ")
                docframe.border_width = 5
                docframe.shadow_type = Gtk::SHADOW_IN

                doctable = Table.new(1, 2)
                doctable.attach(@document_fullsave = CheckButton.new("Full Save").set_active(true), 0, 1, 0, 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                docframe.add(doctable)

                annotsframe = Frame.new(" Annotations ")
                annotsframe.border_width = 5
                annotsframe.shadow_type = Gtk::SHADOW_IN

                annotstable = Table.new(4,2)
                annots =
                [
                    [ @annots_create = CheckButton.new("Create").set_active(true), @annots_import = CheckButton.new("Import").set_active(true) ],
                    [ @annots_delete = CheckButton.new("Delete").set_active(true), @annots_export = CheckButton.new("Export").set_active(true) ],
                    [ @annots_modify = CheckButton.new("Modify").set_active(true), @annots_online = CheckButton.new("Online").set_active(true) ],
                    [ @annots_copy = CheckButton.new("Copy").set_active(true), @annots_sumview = CheckButton.new("Summary View").set_active(true) ]
                ]

                row = 0
                annots.each do |col1, col2|
                    annotstable.attach(col1, 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    annotstable.attach(col2, 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)

                    row = row.succ
                end

                annotsframe.add(annotstable)

                formframe = Frame.new(" Forms ")
                formframe.border_width = 5
                formframe.shadow_type = Gtk::SHADOW_IN

                formtable = Table.new(4,2)
                forms =
                [
                    [ @form_fillin = CheckButton.new("Fill in").set_active(true), @form_spawntemplate = CheckButton.new("Spawn template").set_active(true) ],
                    [ @form_import = CheckButton.new("Import").set_active(true), @form_barcode = CheckButton.new("Barcode plaintext").set_active(true) ],
                    [ @form_export = CheckButton.new("Export").set_active(true), @form_online = CheckButton.new("Online").set_active(true) ],
                    [ @form_submit = CheckButton.new("Submit stand-alone").set_active(true), nil ]
                ]

                row = 0
                forms.each do |col1, col2|
                    formtable.attach(col1, 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    formtable.attach(col2, 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4) unless col2.nil?

                    row = row.succ
                end

                formframe.add(formtable)

                signatureframe = Frame.new(" Signature ")
                signatureframe.border_width = 5
                signatureframe.shadow_type = Gtk::SHADOW_IN

                signaturetable = Table.new(1, 2)
                signaturetable.attach(@signature_modify = CheckButton.new("Modify").set_active(true), 0, 1, 0, 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                signatureframe.add(signaturetable)

                efframe = Frame.new(" Embedded files ")
                efframe.border_width = 5
                efframe.shadow_type = Gtk::SHADOW_IN

                eftable = Table.new(2,2)
                efitems =
                [
                    [ @ef_create = CheckButton.new("Create").set_active(true), @ef_modify = CheckButton.new("Modify").set_active(true) ],
                    [ @ef_delete = CheckButton.new("Delete").set_active(true), @ef_import = CheckButton.new("Import").set_active(true) ]
                ]

                row = 0
                efitems.each do |col1, col2|
                    eftable.attach(col1, 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    eftable.attach(col2, 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)

                    row = row.succ
                end

                efframe.add(eftable)

                vbox.add(docframe)
                vbox.add(annotsframe)
                vbox.add(formframe)
                vbox.add(signatureframe)
                vbox.add(efframe)

                append_page(vbox)
                set_page_title(vbox, "Select Usage Rights to enable")
                set_page_type(vbox, Assistant::PAGE_CONFIRM)
                set_page_complete(vbox, true)
            end

            def create_termination_page
                @lastpage = VBox.new(false, 5)

                @msg_status = Label.new
                @lastpage.pack_start(@msg_status, true, true, 0)

                append_page(@lastpage)
                set_page_title(@lastpage, "Usage Rights have not been enabled")
                set_page_type(@lastpage, Assistant::PAGE_SUMMARY)
            end
        end

        class SignWizard < Assistant
            include SignatureDialogs

            INTRO_PAGE = 0
            KEY_SELECT_PAGE = 1
            PKCS12_IMPORT_PAGE = 2
            KEYPAIR_IMPORT_PAGE = 3
            SIGNATURE_INFO_PAGE = 4
            SIGNATURE_RESULT_PAGE = 5

            def initialize(parent, pdf)
                super()

                @parent = parent

                @pkey, @cert, @ca = nil, nil, []

                create_intro_page
                create_key_selection_page
                create_pkcs12_import_page
                create_keypair_import_page
                create_signature_info_page
                create_termination_page

                set_forward_page_func { |current_page|
                    case current_page
                    when KEY_SELECT_PAGE
                        if @p12button.active? then PKCS12_IMPORT_PAGE else KEYPAIR_IMPORT_PAGE end

                    when PKCS12_IMPORT_PAGE, KEYPAIR_IMPORT_PAGE
                        SIGNATURE_INFO_PAGE

                    else current_page.succ
                    end
                }

                signal_connect('delete_event') { self.destroy }
                signal_connect('cancel') { self.destroy }
                signal_connect('close') { self.destroy }

                signal_connect('apply') {
                    location = @location.text.empty? ? nil : @location.text
                    contact = @email.text.empty? ? nil : @email.text
                    reason = @reason.text.empty? ? nil : @reason.text

                    begin
                        pdf.sign(@cert, @pkey,
                                 ca: @ca,
                                 location: location,
                                 contact: contact,
                                 reason: reason)

                        set_page_title(@lastpage, "Document has been signed")
                        @msg_status.text = "The document has been signed.\n You should consider saving it now."

                        @parent.reload
                    rescue
                        @parent.error("#{$!}: #{$!.backtrace.join($/)}")

                        set_page_title(@lastpage, "Document has not been signed")
                        @msg_status.text = "An error occured during the signature process."
                    end
                }

                set_modal(true)

                show_all
            end

            private

            def create_intro_page
                intro = <<-INTRO.gsub(/^\s+/, '')
                    You are about to sign the current PDF document.
                    Once the document will be signed, no further modification will be allowed.

                    The signature process is based on assymetric cryptography, so you will basically need a public/private RSA key pair (between 1024 and 4096 bits).
                INTRO

                vbox = VBox.new(false, 5)
                vbox.set_border_width(5)

                lbl = Label.new(intro).set_justify(Gtk::JUSTIFY_LEFT).set_wrap(true)

                vbox.pack_start(lbl, true, true, 0)

                append_page(vbox)
                set_page_title(vbox, "Signature Wizard")
                set_page_type(vbox, Assistant::PAGE_INTRO)
                set_page_complete(vbox, true)
            end

            def create_key_selection_page
                vbox = VBox.new(false, 5)

                @rawbutton = RadioButton.new("Import keys from separate PEM/DER encoded files")
                @p12button = RadioButton.new(@rawbutton, "Import keys from a PKCS12 container")

                vbox.pack_start(@rawbutton, true, true, 0)
                vbox.pack_start(@p12button, true, true, 0)

                append_page(vbox)
                set_page_title(vbox, "Choose a key importation method")
                set_page_type(vbox, Assistant::PAGE_CONTENT)
                set_page_complete(vbox, true)
            end

            def create_pkcs12_import_page
                vbox = VBox.new(false, 5)

                hbox = HBox.new(false, 5)
                vbox.pack_start(hbox, true, false, 10)

                @p12filename = Entry.new.set_editable(false).set_sensitive(false)
                choosebtn = Button.new(Gtk::Stock::OPEN)

                choosebtn.signal_connect('clicked') { open_pkcs12_file_dialog(vbox) }

                hbox.pack_start(@p12filename, true, true, 5)
                hbox.pack_start(choosebtn, false, false, 5)

                append_page(vbox)
                set_page_title(vbox, "Import a PKCS12 container")
                set_page_type(vbox, Assistant::PAGE_CONTENT)
            end

            def create_keypair_import_page

                labels =
                [
                    [ "Private RSA key:", @pkeyfilename = Entry.new,  pkeychoosebtn = Button.new(Gtk::Stock::OPEN) ],
                    [ "Public certificate:", @certfilename = Entry.new, certchoosebtn = Button.new(Gtk::Stock::OPEN) ]
                ]

                row = 0
                table = Table.new(2, 3)
                labels.each do |lbl, entry, btn|
                    entry.editable = entry.sensitive = false

                    table.attach(Label.new(lbl).set_alignment(1,0), 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    table.attach(entry, 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    table.attach(btn, 2, 3, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)

                    row = row.succ
                end

                pkeychoosebtn.signal_connect('clicked') { open_private_key_dialog(table) }
                certchoosebtn.signal_connect('clicked') { open_certificate_dialog(table) }

                append_page(table)
                set_page_title(table, "Import a public/private key pair")
                set_page_type(table, Assistant::PAGE_CONTENT)
            end

            def create_signature_info_page
                vbox = VBox.new(false, 5)

                lbl = Label.new("Here are a few optional information you can add with your signature.")
                vbox.pack_start(lbl, true, true, 0)

                labels =
                [
                    [ "Location:", @location = Entry.new ],
                    [ "Contact:", @email = Entry.new ],
                    [ "Reason:", @reason = Entry.new ]
                ]

                row = 0
                table = Table.new(4, 3)
                labels.each do |label|
                    table.attach(Label.new(label[0]).set_alignment(1,0), 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    table.attach(label[1], 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)

                    row = row.succ
                end

                vbox.pack_start(table, true, true, 0)

                append_page(vbox)
                set_page_title(vbox, "Fill in signature details")
                set_page_type(vbox, Assistant::PAGE_CONFIRM)
                set_page_complete(vbox, true)
            end

            def create_termination_page
                @lastpage = VBox.new(false, 5)

                @msg_status = Label.new
                @lastpage.pack_start(@msg_status, true, true, 0)

                append_page(@lastpage)
                set_page_title(@lastpage, "Document has not been signed")
                set_page_type(@lastpage, Assistant::PAGE_SUMMARY)
            end
        end
    end

end
