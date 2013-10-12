# encoding: utf-8

require 'multi_json'
require 'hdo/storting_importer'
require 'hdo/vote_inferrer'
require 'hdo/import/persister'
require 'hdo/import/cli'
require 'hdo/one_dimensional_hierarchical_clusterer'

module Hdo
  module Import
    class Error < StandardError
    end

    class IncompatiblePartyMembershipError < Error
    end

    class IncompatibleCommitteeMembershipError < Error
    end
  end
end