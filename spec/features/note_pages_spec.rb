require "spec_helper"

describe "note pages" do
  subject { page }

  include ActivityMacros

  before do
    # avoid messing around with any existing templates:
    allow(NoteTemplate).to receive(:pwd).and_return(Pathname.new('tmp/templates/notes'))
    FileUtils.mkdir_p(Rails.root.join("tmp","templates","notes"))
    login_to_project_as_user
    @node    = create(:node)
  end

  after(:all) do
    FileUtils.rm_rf('tmp/templates')
  end

  describe "show page" do
    before do
      text = "#[Title]#\nMy note\n\n#[Description]#\nMy description"
      @note = create(:note, node: @node, text: text)
      create_activities
      visit node_note_path(@node, @note)
    end

    let(:create_activities) { nil }

    it "shows the note's contents" do
      should have_selector "h4", text: "Title"
      should have_selector "p",  text: "My note"
      should have_selector "h4", text: "Description"
      should have_selector "p",  text: "My description"
    end

    let(:trackable) { @note }
    it_behaves_like "a page with an activity feed"

    describe "clicking 'delete'" do
      let(:submit_form) { click_link "delete" }

      it "deletes the note and redirects to the node's page" do
        id = @note.id
        submit_form
        expect(Note.find_by_id(id)).to be_nil
        expect(current_path).to eq node_path(@node)
      end

      let(:model) { @note }
      include_examples "creates an Activity", :destroy
    end
  end

  describe "edit page" do
    before do
      @note = create(:note, node: @node)
      visit edit_node_note_path(@node, @note)
    end

    let(:submit_form) { click_button "Update Note" }

    it "has a form to edit the note" do
      should have_field :note_text
      should have_field :note_category_id
    end

    it "uses the full-screen editor plugin" # TODO

    it_behaves_like "a form with a help button"

    describe "submitting the form with valid information" do

      before do
        fill_in :note_text, with: 'New note text'
      end

      it "updates the note" do
        submit_form
        expect(@note.reload.text).to eq "New note text"
      end

      it "shows the updated note" do
        submit_form
        expect(current_path).to eq node_note_path(@node, @note)
        expect(page).to have_content "New note text"
      end

      let(:model) { @note }
      include_examples "creates an Activity", :update
    end

    describe "submitting the form with invalid information" do
      before { fill_in :note_text, with: "a"*65536 }

      it "doesn't update the note" do
        expect{submit_form}.not_to change{@note.reload.text}
      end

      include_examples "doesn't create an Activity"

      it "shows the form again with an error message" do
        submit_form
        should have_field :note_text
        should have_selector ".alert.alert-error"
      end
    end
  end


  describe "new page" do
    let(:content) { "This is an example note" }
    let(:path)    { Rails.root.join("tmp", "templates", "notes", "tmpnote.txt") }

    # Create the dummy NoteTemplate:
    before do
      File.write(path, content)
      visit new_node_note_path(@node, params)
    end
    after { File.delete(path) }

    let(:submit_form) { click_button "Create Note" }

    context "when no template is specified" do
      let(:params) { {} }

      it "displays a blank textarea" do
        textarea = find("textarea#note_text")
        expect(textarea.value.strip).to eq ""
      end

      it "uses the textile-editor plugin"

      it_behaves_like "a form with a help button"

      describe "submitting the form with valid information" do
        let(:new_note) { @node.notes.order('created_at ASC').last }

        before do
          # "fill_in :note_text" doesn't work for some reason :(
          find("#note_text").set('This is a note')
        end

        it "creates a new note from the current user" do
          expect{submit_form}.to change{@node.notes.count}.by(1)
          expect(new_note.author).to eq @logged_in_as.email
        end

        it "shows the newly created note" do
          submit_form
          expect(current_path).to eq node_note_path(@node, new_note)
          expect(page).to have_content "This is a note"
        end

        include_examples "creates an Activity", :create, Note
      end

      describe "submitting the form with invalid information" do
        before { fill_in :note_text, with: "a"*65536 }

        it "doesn't create a note" do
          expect{submit_form}.not_to change{Note.count}
        end

        include_examples "doesn't create an Activity"

        it "shows the form again with an error message" do
          submit_form
          should have_field :note_text
          should have_selector ".alert.alert-error"
        end
      end
    end

    context "when a NoteTemplate is specified" do
      let(:params)  { { template: "tmpnote" } }

      it "pre-populates the textarea with the template contents" do
        textarea = find("textarea#note_text")
        expect(textarea.value.strip).to eq content
      end

      it "uses the textile-editor plugin"
    end
  end
end
