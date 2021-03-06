module Hdo
  module Import
    class Persister
      attr_writer :log

      def initialize
        @log = Logger.new(STDOUT)
      end

      def import_votes(votes, opts = {})
        imported_votes = transaction do
          votes.map { |e| import_vote(e) }
        end

        infer imported_votes if opts[:infer]
      end

      def import_representatives(reps)
        transaction do
          reps.each { |e| import_representative(e) }
        end
      end

      def import_propositions(propositions)
        transaction do
          propositions.each { |e| import_proposition(e) }
        end
      end

      def import_promises(promises)
        transaction do
          promises.each { |e| import_promise(e) }
        end
      end

      def import_parties(parties)
        transaction do
          parties.each { |e| import_party(e) }
        end
      end

      def import_committees(committees)
        transaction do
          committees.each { |e| import_committee(e) }
      end
      end

      def import_categories(categories)
        transaction do
          categories.each { |e| import_category(e) }
        end
      end

      def import_districts(districts)
        transaction do
          districts.each { |e| import_district(e) }
        end
      end

      def import_parliament_periods(parliament_periods)
        transaction do
          parliament_periods.each { |e| import_parliament_period(e) }
        end
      end

      def import_parliament_sessions(parliament_sessions)
        transaction do
          parliament_sessions.each { |e| import_parliament_session(e) }
        end
      end

      def import_parliament_period(period)
        log_import period
        period.validate!

        record = ParliamentPeriod.find_or_initialize_by_external_id(period.external_id)
        record.start_date = period.start_date
        record.end_date = period.end_date

        record.save!
      end

      def import_parliament_session(session)
        log_import session
        session.validate!

        record = ParliamentSession.find_or_initialize_by_external_id(session.external_id)
        record.start_date = session.start_date
        record.end_date = session.end_date

        record.save!
      end

      def import_party(party)
        log_import party
        party.validate!

        record = Party.find_or_create_by_external_id party.external_id
        record.name = party.name
        record.save!

        record
      end

      def import_committee(committee)
        log_import committee
        committee.validate!

        c = Committee.find_or_create_by_external_id committee.external_id
        c.update_attributes! :name => committee.name

        c
      end

      def import_category(category)
        log_import category
        category.validate!

        parent = Category.find_or_create_by_external_id category.external_id
        parent.name = category.name
        parent.main = true
        parent.save!

        category.children.each do |subcategory|
          log_import subcategory
          child = Category.find_or_create_by_external_id(subcategory.external_id)
          child.name = subcategory.name
          child.save!

          parent.children << child
        end
      end

      def import_district(district)
        log_import district
        district.validate!

        d = District.find_or_create_by_external_id district.external_id
        d.update_attributes! :name => district.name

        d
      end

      def import_parliament_issue(issue, details)
        transaction {
          log_import issue
          issue.validate!

          committee  = issue.committee && Committee.find_by_name!(issue.committee)
          categories = issue.categories.map { |e| Category.find_by_name! e }
          links      = details.links.map { |e| find_or_create_link(e) }.sort_by(&:href)

          record = ParliamentIssue.find_or_create_by_external_id issue.external_id
          record.update_attributes!(
            :document_group => issue.document_group,
            :issue_type     => issue.type, # AR doesn't like :type as a column name
            :status         => issue.status,
            :last_update    => Time.parse(issue.last_update),
            :reference      => issue.reference.truncate(250),
            :summary        => issue.summary,
            :description    => issue.description,
            :committee      => committee,
            :categories     => categories,
            :links          => links
          )

          record
        }
      end

      VOTE_RESULTS = {
        "for"     => 1,
        "absent"  => 0,
        "against" => -1
      }

      def import_vote(xvote)
        log_import xvote
        xvote.validate!

        vote = Vote.find_by_external_id xvote.external_id

        unless vote
          # https://github.com/holderdeord/hdo-site/issues/317
          # using enacted here handles the case of alternate votes
          vote = Vote.where(time: Time.parse(xvote.time), enacted: xvote.enacted).first

          if vote
            vote.update_attributes!(external_id: xvote.external_id)
          end
        end

        unless vote
          vote = Vote.new
          vote.external_id = xvote.external_id
        end

        xvote.external_issue_id.split(',').each do |xeid|
          parliament_issue = ParliamentIssue.find_by_external_id!(xeid)

          unless vote.parliament_issues.include?(parliament_issue)
            vote.parliament_issues << parliament_issue
          end
        end

        attributes = {
          enacted:  xvote.enacted?,
          personal: xvote.personal?,
          subject:  xvote.subject,
          comment:  xvote.comment,
          time:     Time.parse(xvote.time),
        }

        unless vote.inferred?
          # don't overwrite inferred counts.

          attributes.merge!(
            for_count:     Integer(xvote.counts.for),
            against_count: Integer(xvote.counts.against),
            absent_count:  Integer(xvote.counts.absent),
          )
        end

        vote.update_attributes!(attributes)

        xvote.representatives.each do |xrep|
          result = VOTE_RESULTS[xrep.vote_result] or raise "invalid vote result: #{result_text.inspect}"
          rep = find_or_import_representative(xrep)

          if rep.party_membership_at(attributes[:time]).nil?
            rep = import_representative(xrep)
            if rep.party_membership_at(attributes[:time]).nil?
              raise "vote cast without party membership: #{xrep.inspect} @ #{xvote.time} (#{xvote.subject})"
            end
          end

          res = VoteResult.find_or_create_by_representative_id_and_vote_id(rep.id, vote.id)
          res.result = result
          res.save!
        end

        xvote.propositions.each do |e|
          import_proposition(e, vote)
        end

        vote.save!
        vote
      end

      def import_representative(representative)
        log_import representative
        representative.validate!

        district = District.find_by_name!(representative.district)
        dob = Time.parse(representative.date_of_birth)

        if representative.date_of_death
          dod = Time.parse(representative.date_of_death)
          dod = nil if dod.year == 1
        else
          dod = nil
        end

        rec = Representative.find_or_create_by_external_id representative.external_id
        attrs = {
          :first_name    => representative.first_name,
          :last_name     => representative.last_name,
          :district      => district,
          :date_of_birth => dob,
          :date_of_death => dod
        }

        attrs[:email] = representative.email
        rec.update_attributes!(attrs)


        PartyMembershipUpdater.new(rec, representative.parties).update
        CommitteeMembershipUpdater.new(rec, representative.committees).update

        rec
      end

      def import_proposition(xprop, vote = nil)
        log_import xprop
        xprop.validate!

        return if xprop.external_id == "-1" # https://github.com/holderdeord/hdo-site/issues/138

        prop = Proposition.find_or_create_by_external_id(xprop.external_id)

        attributes = {
          description: xprop.description,
          on_behalf_of: xprop.on_behalf_of,
          body: xprop.body
        }

        if vote && !prop.votes.include?(vote)
          prop.votes << vote
        end

        prop.update_attributes attributes
        prop.save!

        if xprop.delivered_by
          rep = find_or_import_representative(xprop.delivered_by)
          prop.add_proposer(rep) unless prop.proposers.include?(rep)
        end

        prop.source_guess.each do |xid|
          party = Party.find_by_external_id(xid)

          unless prop.proposers.include?(party)
            prop.add_proposer(party, inferred: true)
          end
        end

        prop
      end

      def import_promise(promise)
        log_import promise

        unless promise.valid?
          @log.error "promise is not valid: #{promise.inspect}"
          return
        end

        categories = Category.where(name: promise.categories)
        not_found = promise.categories - categories.map(&:name)

        if not_found.any?
          @log.error "promise #{promise.external_id}: invalid categories #{not_found.inspect}"
          return
        end

        if promise.categories.empty?
          @log.error "promise #{promise.external_id}: no categories"
          return
        end

        promisor = Party.find_by_external_id(promise.promisor) || Government.find_by_name(promise.promisor)
        if promisor.nil?
          @log.error "promise #{promise.external_id}: unknown party/government: #{promise.promisor}"
          return
        end

        parliament_period = ParliamentPeriod.find_by_external_id(promise.period)
        unless parliament_period
          @log.error "promise #{promise.external_id}: unknown parliament period: #{parliament_period}"
          return
        end

        pr = Promise.find_or_create_by_external_id(promise.external_id)

        if pr.new_record?
          duplicate = Promise.where(body: promise.body, parliament_period_id: parliament_period).first
          if duplicate
            @log.error "promise #{promise.external_id}: duplicate of #{duplicate.external_id}"
            return
          end
        end

        pr.update_attributes(
          promisor: promisor,
          general: promise.general?,
          categories: categories,
          source: promise.source,
          page: promise.page,
          body: promise.body,
          parliament_period: parliament_period
        )

        unless pr.save
          @log.error "promise #{promise.external_id}: #{pr.errors.full_messages.to_sentence}"
          return
        end

        pr
      end

      def infer_all_votes
        infer Vote.non_personal
      end

      def infer_current_session
        infer ParliamentSession.current.votes
      end

      private

      def log_import(obj)
        @log.info "importing #{obj.short_inspect}"
      end

      def transaction(&blk)
        ActiveRecord::Base.transaction(&blk)
      end

      def find_or_import_representative(xrep)
        Representative.find_by_external_id(xrep.external_id) || import_representative(xrep)
      end

      def find_or_create_link(xlink)
        link = Link.where(href: xlink.fetch('url')).first

        link ||= Link.create!(
          external_id:    xlink['external_id'],
          title:          xlink['title'],
          href:           xlink.fetch('url'),
          link_type:      xlink['type'],
          link_sub_type:  xlink['subtype']
        )

        link
      end

      def infer(imported_votes)
        non_personal_votes = imported_votes.select { |v| v.non_personal? }

        inferrer     = VoteInferrer.new(non_personal_votes)
        inferrer.log = @log

        inferrer.infer!
      end

    end # Persister
  end # Import
end # Hdo