# -*- coding: utf-8 -*-
require 'spec_helper'

describe Party do
  it 'has a valid blueprint' do
    Party.make!
  end

  it 'is invalid without a name' do
    Party.make(name: nil).should be_invalid
  end

  it 'is invalid without unique name' do
    party = Party.make!
    Party.make(name: party.name).should_not be_valid
  end

  it "knows if it is in government" do
    p = Party.make!
    Government.make!(:parties => [p])

    p.should be_in_government
  end

  it 'is invalid without an external_id' do
    Party.make(external_id: nil).should be_invalid
  end

  it 'is invalid without a unique external_id' do
    party = Party.make!
    Party.make(external_id: party.external_id).should be_invalid
  end

  it 'will not add the same promise twice' do
    party = Party.make!

    promise = Promise.make!(promisor: party)
    party.promises.count.should == 1

    party.promises << promise
    party.promises.count.should == 1
  end

  it 'knows its current representatives' do
    party = Party.make!

    current_rep = Representative.make!(:attending)
    current_rep.party_memberships.create!(party: party, start_date: 1.month.ago)

    previous_rep = Representative.make!(:attending)
    previous_rep.party_memberships.create!(party: party, start_date: 2.months.ago, end_date: 1.month.ago)

    party.current_representatives.should == [current_rep]
    party.representatives_at(Time.current).should == [current_rep]
    party.representatives_at(40.days.ago).should == [previous_rep]
    party.representatives.should == [current_rep, previous_rep]
  end

  it 'does not include non-attending representatives in current representatives' do
    party = Party.make!

    rep = Representative.make!(:attending)
    rep.party_memberships.create!(party: party, start_date: 1.month.ago)
    party.current_representatives.should include(rep)

    rep.update_attributes!(attending: false)
    party.current_representatives.should == []
  end

  it 'destroys dependent memeberships when destroyed' do
    party = Party.make!
    rep = Representative.make!

    party.party_memberships.create!(representative: rep, start_date: 1.month.ago)
    rep.party_memberships.size.should == 1

    party.destroy

    rep.party_memberships.should == []
  end

  it "should know the party's short name" do
    Party.make!(external_id: 'A', name: 'Arbeiderpartiet').short_name.should == 'Ap'
    Party.make!(external_id: 'V', name: 'Venstre').short_name.should == 'Venstre'
    Party.make!(external_id: 'H', name: 'Høyre').short_name.should == 'Høyre'
    Party.make!(external_id: 'KrF', name: 'Kristelig Folkeparti').short_name.should == 'KrF'
    Party.make!(external_id: 'FrP', name: 'Fremskrittspartiet').short_name.should == 'FrP'
    Party.make!(external_id: 'Sp', name: 'Senterpartiet').short_name.should == 'Sp'
    Party.make!(external_id: 'MDG', name: 'Miljø...').short_name.should == 'MDG'
  end
end
