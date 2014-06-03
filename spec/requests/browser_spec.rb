require 'spec_helper'
SimpleCov.command_name 'requests'

describe Hdo::Application do
  it "should load the front page" do
    front_page.get
  end

  it 'autocompletes a search for issues' do
    issue = Issue.create!(status: "published", title: "Fjerne formueskatten")
    Issue.__elasticsearch__.refresh_index!

    menu = front_page.get.menu
    menu.search_for('skatt')

    result = wait(10).until { menu.autocomplete_results.first }
    result.title.should == "Fjerne formueskatten"
  end

  context 'issue editor' do
    let(:user) {
      pass = 'foo123'
      User.make!(password: pass, password_confirmation: pass, role: 'admin')
    }

    let(:page) { admin_issue_editor_page.get }

    before do
      ParliamentSession.make!(:current)
      admin_login_page.get.login_as(user.email, user.password)
    end

    it 'can create a basic issue' do
      page.intro_section.fill(
        title: "Do the right thing @ #{Time.now}",
        description: "People sometimes disagree."
      )

      page.save.should be_true, page.error_messages
      Issue.count.should == 1
    end

    it 'can create an issue with all features' do
      ParliamentPeriod.make!(:current)
      Proposition.make!
      Party.make!
      Promise.make!

      refresh_indeces

      page.intro_section.fill(title: "Do the right thing @ #{Time.now}", description: 'test')
      page.propositions_section.open

      # page.propositons_section.find
      # page.propositons_section.select_first_proposition
      # page.propositons_section.use_cart

      page.promises_section.open

      # page.promises_section.find
      # page.promises_section.select_first_promise
      # page.promises_section.use_cart

      page.positions_section.open
      # page.positions_section.new(title: 'Position A', description: 'Position A desc', parties: [Party.first.name])

      page.party_comments_section.open

      # page.party_comments_section.new(title: 'Comment A', description: 'Comment A desc', party: Party.first.name)

      i = Issue.first
      i.should_not be_nil
      i.proposition_connections.size.should == 1
      i.promise_connections.size.should     == 1
      i.positions.size.should               == 1
      i.party_comments.size.should          == 1
    end
  end
end
