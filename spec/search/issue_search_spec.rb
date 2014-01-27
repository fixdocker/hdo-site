# encoding: utf-8

require 'spec_helper'

describe Issue, :search do
  def issue_titled(title)
    issue = Issue.make!(title: title, status: 'published')
    refresh_index

    issue
  end

  it 'finds "formueskatten" for query "skatt"' do
    issue = issue_titled 'fjerne formueskatten'
    results = results_for 'skatt'

    results.should_not be_empty
    results.first._id.to_i.should == issue.id
  end

  it 'does synonym mappings' do
    issue_titled 'miljøvern'
    issue_titled 'klima'

    results_for('miljøvern').size.should == 2
    results_for('klima').size.should == 2
  end

  context 'refresh on association update' do
    it 'updates the index when associated categories change' do
      category = Category.make!
      issue = Issue.make!(status: 'published', categories: [category])
      refresh_index

      results_for('*').size.should == 1

      result = Issue.search('*').results.first
      result.categories.first.name.should == category.name

      category.update_attributes!(name: 'shrimp')
      refresh_index

      result = Issue.search('*').results.first
      result.categories.first.name.should == category.name
    end

    it 'does not update the index if categories change while the issue is unpublished' do
      category = Category.make!
      issue = Issue.make!(status: 'in_progress', categories: [category])
      refresh_index

      Issue.search('*').results.size.should == 0

      category.update_attributes!(name: 'shrimp')
      refresh_index

      Issue.search('*').results.size.should == 0
    end
  end

  it 'indexes tags' do
    issue = issue_titled 'foo'
    issue.tag_list << 'bar'
    issue.save!

    refresh_index

    results = results_for('bar')
    results.size.should == 1

    results.first._id.to_i.should == issue.id
  end

  it 'removes issues from index on unpublishing' do
    issue = issue_titled 'save world'
    refresh_index

    issue.update_attributes!(status: 'publishable')
    refresh_index

    results_for('world').count.should be_zero
  end
end
