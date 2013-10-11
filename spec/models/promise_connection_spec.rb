# encoding: utf-8

require 'spec_helper'

describe PromiseConnection do
  it 'should have a valid blueprint' do
    PromiseConnection.make.should be_valid
  end

  it 'should be invalid without a promise' do
    PromiseConnection.make(promise: nil).should be_invalid
  end

  it 'should be invalid without a issue' do
    PromiseConnection.make(issue: nil).should be_invalid
  end

  it 'validates the status values' do
    pc = PromiseConnection.make(override: 100)

    pc.status = 'for'
    pc.should be_valid

    pc.status = 'against'
    pc.should be_valid

    pc.status = 'related'
    pc.should be_valid

    pc.status = 'unrelated'
    pc.should_not be_valid
  end

  it 'has a translation for the status' do
    pc = PromiseConnection.make

    I18n.with_locale :nb do
      pc.status = 'for'
      pc.status_text.should == 'støtter saken'

      pc.status = 'against'
      pc.status_text.should == 'støtter ikke saken'

      pc.status = 'related'
      pc.status_text.should == 'relatert til saken'

      pc.status = 'unrelated'
      expect { pc.status_text }.to raise_error
    end
  end

  it 'disallows promises from the next period' do
    current_period = ParliamentPeriod.make!(external_id: '2009-2013')
    next_period    = ParliamentPeriod.make!(external_id: '2013-2017')

    current_promise = Promise.make!(parliament_period: current_period)
    next_promise = Promise.make!(parliament_period: next_period)

    PromiseConnection.make(status: 'for', promise: current_promise, override: 100).should be_valid
    PromiseConnection.make(status: 'for', promise: next_promise, override: 100).should_not be_valid
  end

  it 'allows related promises from the next period' do
    next_period    = ParliamentPeriod.make!(external_id: '2013-2017')
    next_promise = Promise.make!(parliament_period: next_period)

    PromiseConnection.make(promise: next_promise, status: 'related').should be_valid
  end

  it 'allows manual overrides' do
    pc = PromiseConnection.make
    pc.should_not be_overridden

    pc.override = -1
    pc.should be_overridden
    pc.should_not be_valid

    pc.override = 0
    pc.should be_overridden
    pc.should be_valid

    pc.override = 1
    pc.should be_overridden
    pc.should be_valid

    pc.override = 100
    pc.should be_overridden
    pc.should be_valid

    pc.override = 101
    pc.should be_overridden
    pc.should_not be_valid
  end

end
