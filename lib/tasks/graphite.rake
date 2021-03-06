namespace :graphite do
  task :env => :environment do
    require 'hdo/stats/accountability_scorer'
  end

  task :facebook => :env do
    g = Hdo::Utils::GraphiteReporter.instance
    Hdo::Utils::FacebookStats.new.stats.each { |k, v| g.add k, v }
  end

  task :twitter => :env do
    g = Hdo::Utils::GraphiteReporter.instance

    Hdo::Utils::TwitterStats.new.stats.each { |k, v| g.add k, v }
  end

  task :stortinget => :env do
    g = Hdo::Utils::GraphiteReporter.instance

    g.add 'stortinget.count.votes',           Vote.count
    g.add 'stortinget.count.propositions',    Proposition.count
    g.add 'stortinget.count.issues',          ParliamentIssue.count
    g.add 'stortinget.count.representatives', Representative.count
  end

  task :holderdeord => :env do
    g = Hdo::Utils::GraphiteReporter.instance

    g.add 'hdo.count.issues.total',               Issue.count
    g.add 'hdo.count.issues.published',           Issue.published.count

    g.add 'hdo.count.promises.total',             Promise.count
    g.add 'hdo.count.promises.connected',         PromiseConnection.includes(:issue).where("issues.status" => "published").select(:promise_id).count
    g.add 'hdo.count.propositions.connected',     PropositionConnection.includes(:issue).where("issues.status" => "published").select(:proposition_id).count

    g.add 'hdo.count.representatives.opted_out',  Representative.opted_out.count
    g.add 'hdo.count.representatives.registered', Representative.registered.count

    previous_period = ParliamentPeriod.previous
    current_period  = ParliamentPeriod.current
    previous_session = ParliamentSession.previous
    current_session = ParliamentSession.current

    [previous_period, current_period].compact.each do |period|
      leaderboard = Hdo::Stats::Leaderboard.new(Issue.published, period)
      leaderboard.by_party.each do |party, counts|
        counts.each do |key, count|
          g.add "hdo.count.issues.#{period.name}.#{party.slug}.#{key}", count
        end
      end
    end

    [previous_session, current_session].each do |session|
      counts = Hdo::Stats::PropositionCounts.from_session(session.name)

      g.add "hdo.count.propositions.#{session.name}.published", counts.published
      g.add "hdo.count.propositions.#{session.name}.pending", counts.pending
      g.add "hdo.count.propositions.#{session.name}.total", counts.total
    end
  end

  desc 'Fetch and submit data to Graphite'
  task :submit => %w[facebook twitter stortinget holderdeord] do
    Hdo::Utils::GraphiteReporter.instance.submit
  end


  desc 'Print data that would be submitted to Graphite'
  task :print => %w[facebook stortinget holderdeord] do
    Hdo::Utils::GraphiteReporter.instance.print
  end
end
