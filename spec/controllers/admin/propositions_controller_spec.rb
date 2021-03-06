require 'spec_helper'

describe Admin::PropositionsController do
  before { sign_in User.make! }
  before { ParliamentSession.make!(start_date: 1.month.ago, end_date: 1.month.from_now) }

  it 'should get :index' do
    get :index

    response.should be_ok
    response.should have_rendered :index
  end

  it 'should get :edit' do
    prop = Proposition.make!(:with_vote)

    get :edit, id: prop

    response.should be_ok
    response.should have_rendered :edit
  end


  it 'should post :update' do
    prop = Proposition.make!(:with_vote)
    prop.simple_description.should be_nil
    prop.simple_body.should be_nil

    attrs = {simple_description: "foo", simple_body: "bar", issues: []}

    post :update, id: prop, save: '', proposition: attrs
    response.should redirect_to(edit_admin_proposition_path(prop))

    prop.reload.simple_description.should == "foo"
  end

  it 'should treats empty string as nil' do
    prop = Proposition.make!(:with_vote)
    prop.simple_description.should be_nil
    prop.simple_body.should be_nil

    attrs = {simple_description: "", simple_body: "", issues: []}

    post :update, id: prop, save: '', proposition: attrs
    response.should redirect_to(edit_admin_proposition_path(prop))

    prop.reload

    prop.simple_description.should be_nil
    prop.simple_body.should be_nil
  end

  it 'should post :update and redirect to the next proposition' do
    props = [Proposition.make!(:with_vote), Proposition.make!(:with_vote)]

    post :update, id: props.first, save_next: '', proposition: {simple_description: 'foo'}, next: props.last

    response.should redirect_to(edit_admin_proposition_path(props.last))
  end

  it 'should update issues' do
    issue = Issue.make!(proposition_connections: [])
    prop = Proposition.make!(:with_vote)

    issue.proposition_connections.should be_empty

    post :update, id: prop, save: '', proposition: {issues: ["", issue.id]}
    response.should redirect_to(edit_admin_proposition_path(prop))

    pc = issue.reload.proposition_connections.first
    pc.should_not be_nil
    pc.proposition.should == prop
  end

  it 'should update proposers' do
    rep   = Representative.make!
    party = Party.make!
    prop  = Proposition.make!(:with_vote)

    prop.proposers.should be_empty
    proposer_strings = ["#{rep.class}-#{rep.id}", "#{party.class}-#{party.id}"]

    post :update, id: prop, save: '', proposers: proposer_strings, proposition: {}
    response.should redirect_to(edit_admin_proposition_path(prop))

    prop.reload.proposers.should == [rep, party]
  end

  it 'should delete proposers' do
    rep = Representative.make!
    prop = Proposition.make!(:with_vote)
    prop.add_proposer rep

    prop.reload.proposers.should_not be_empty

    post :update, id: prop, save: '' , proposers: nil, proposition: {}
    response.should redirect_to(edit_admin_proposition_path(prop))

    prop.reload.proposers.should be_empty
  end
end
