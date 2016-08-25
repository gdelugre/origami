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
                file_chooser_dialog('Choose a private RSA key', '*.key', '*.pem', '*.der') do
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
            end

            def open_certificate_dialog(page)
                file_chooser_dialog('Choose a x509 certificate', '*.crt', '*.cer', '*.pem', '*.der') do
                    begin
                        @cert = OpenSSL::X509::Certificate.new(File.binread(dialog.filename))

                        @certfilename.set_text(dialog.filename)
                        set_page_complete(page, true) if @pkey

                    rescue
                        @parent.error("Error loading file '#{File.basename(dialog.filename)}'")

                        @cert = nil
                        @certfilename.text = ""
                        set_page_complete(page, false)
                    ensure
                        @ca = [] # Shall be added to the GUI
                    end
                end
            end

            def open_pkcs12_file_dialog(page)

                file_chooser_dialog('Open PKCS12 container', '*.pfx', '*.p12') do
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

            def file_chooser_dialog(title, *patterns)
                dialog = FileChooserDialog.new(title,
                            @parent,
                            FileChooser::ACTION_OPEN,
                            nil,
                            [Stock::CANCEL, Dialog::RESPONSE_CANCEL],
                            [Stock::OPEN, Dialog::RESPONSE_ACCEPT])

                filter = FileFilter.new
                patterns.each do |pattern|
                    filter.add_pattern(pattern)
                end

                dialog.set_filter(filter)

                if dialog.run == Dialog::RESPONSE_ACCEPT
                    yield(dialog)
                end

                dialog.destroy
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
                [
                    [ Origami::UsageRights::Rights::DOCUMENT_FULLSAVE, @document_fullsave ],

                    [ Origami::UsageRights::Rights::ANNOTS_CREATE, @annots_create ],
                    [ Origami::UsageRights::Rights::ANNOTS_DELETE, @annots_delete ],
                    [ Origami::UsageRights::Rights::ANNOTS_MODIFY, @annots_modify ],
                    [ Origami::UsageRights::Rights::ANNOTS_COPY, @annots_copy ],
                    [ Origami::UsageRights::Rights::ANNOTS_IMPORT, @annots_import ],
                    [ Origami::UsageRights::Rights::ANNOTS_EXPORT, @annots_export ],
                    [ Origami::UsageRights::Rights::ANNOTS_ONLINE, @annots_online ],
                    [ Origami::UsageRights::Rights::ANNOTS_SUMMARYVIEW, @annots_sumview ],

                    [ Origami::UsageRights::Rights::FORM_FILLIN, @form_fillin ],
                    [ Origami::UsageRights::Rights::FORM_IMPORT, @form_import ],
                    [ Origami::UsageRights::Rights::FORM_EXPORT, @form_export ],
                    [ Origami::UsageRights::Rights::FORM_SUBMITSTANDALONE, @form_submit ],
                    [ Origami::UsageRights::Rights::FORM_SPAWNTEMPLATE, @form_spawntemplate ],
                    [ Origami::UsageRights::Rights::FORM_BARCODEPLAINTEXT, @form_barcode ],
                    [ Origami::UsageRights::Rights::FORM_ONLINE, @form_online ],

                    [ Origami::UsageRights::Rights::SIGNATURE_MODIFY, @signature_modify ],

                    [ Origami::UsageRights::Rights::EF_CREATE, @ef_create ],
                    [ Origami::UsageRights::Rights::EF_DELETE, @ef_delete ],
                    [ Origami::UsageRights::Rights::EF_MODIFY, @ef_modify ],
                    [ Origami::UsageRights::Rights::EF_IMPORT, @ef_import ],
                ].select { |_, button| button.active? }
                 .map { |right, _| right }
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

            def create_rights_frame(name)
                frame = Frame.new(name)
                frame.border_width = 5
                frame.shadow_type = Gtk::SHADOW_IN

                frame
            end

            def create_document_rights_frame
                frame = create_rights_frame(" Document ")

                @document_fullsave = CheckButton.new("Full Save").set_active(true)

                doc_table = Table.new(1, 2)
                doc_table.attach(@document_fullsave, 0, 1, 0, 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                frame.add(doc_table)
            end

            def create_annotations_rights_frame
                frame = create_rights_frame(" Annotations ")

                annots_table = Table.new(4, 2)
                annots =
                [
                    [ @annots_create = CheckButton.new("Create"), @annots_import = CheckButton.new("Import") ],
                    [ @annots_delete = CheckButton.new("Delete"), @annots_export = CheckButton.new("Export") ],
                    [ @annots_modify = CheckButton.new("Modify"), @annots_online = CheckButton.new("Online") ],
                    [ @annots_copy = CheckButton.new("Copy"), @annots_sumview = CheckButton.new("Summary View") ]
                ]

                annots.each_with_index do |cols, row|
                    col1, col2 = cols

                    col1.active = true
                    col2.active = true

                    annots_table.attach(col1, 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    annots_table.attach(col2, 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                end

                frame.add(annots_table)
            end

            def create_form_rights_frame
                frame = create_rights_frame(" Forms ")

                form_table = Table.new(4, 2)
                forms =
                [
                    [ @form_fillin = CheckButton.new("Fill in"), @form_spawntemplate = CheckButton.new("Spawn template") ],
                    [ @form_import = CheckButton.new("Import"), @form_barcode = CheckButton.new("Barcode plaintext") ],
                    [ @form_export = CheckButton.new("Export"), @form_online = CheckButton.new("Online") ],
                    [ @form_submit = CheckButton.new("Submit stand-alone"), nil ]
                ]

                forms.each_with_index do |cols, row|
                    col1, col2 = cols

                    col1.active = true
                    col2.active = true unless col2.nil?

                    form_table.attach(col1, 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    form_table.attach(col2, 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4) unless col2.nil?
                end

                frame.add(form_table)
            end

            def create_signature_rights_frame
                frame = create_rights_frame(" Signature ")

                @signature_modify = CheckButton.new("Modify").set_active(true)

                signature_table = Table.new(1, 2)
                signature_table.attach(@signature_modify, 0, 1, 0, 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                frame.add(signature_table)
            end

            def create_embedded_files_rights_frame
                frame = create_rights_frame(" Embedded files ")

                ef_table = Table.new(2,2)
                ef_buttons =
                [
                    [ @ef_create = CheckButton.new("Create"), @ef_modify = CheckButton.new("Modify") ],
                    [ @ef_delete = CheckButton.new("Delete"), @ef_import = CheckButton.new("Import") ]
                ]

                ef_buttons.each_with_index do |cols, row|
                    col1, col2 = cols

                    col1.active = true
                    col2.active = true

                    ef_table.attach(col1, 0, 1, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                    ef_table.attach(col2, 1, 2, row, row + 1, Gtk::EXPAND | Gtk::FILL, Gtk::SHRINK, 4, 4)
                end

                frame.add(ef_table)
            end

            def create_rights_selection_page
                vbox = VBox.new(false, 5)

                vbox.add create_document_rights_frame
                vbox.add create_annotations_rights_frame
                vbox.add create_form_rights_frame
                vbox.add create_signature_rights_frame
                vbox.add create_embedded_files_rights_frame

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
