namespace :graphite do
  task :facebook => :environment do
    g = Hdo::Utils::GraphiteReporter.instance

    Hdo::Utils::FacebookStats.new.stats.each do |key, value|
      g.add key, value
    end
  end

  task :stortinget => :environment do
    g = Hdo::Utils::GraphiteReporter.instance

    g.add 'stortinget.count.votes',           Vote.count
    g.add 'stortinget.count.propositions',    Proposition.count
    g.add 'stortinget.count.issues',          ParliamentIssue.count
    g.add 'stortinget.count.representatives', Representative.count
  end

  task :holderdeord => :environment do
    g = Hdo::Utils::GraphiteReporter.instance

    g.add 'hdo.count.issues.total',               Issue.count
    g.add 'hdo.count.issues.published',           Issue.published.count
    g.add 'hdo.count.questions.total',            Question.count
    g.add 'hdo.count.questions.answered',         Question.answered.count
    g.add 'hdo.count.questions.unanswered',       Question.unanswered.count
    g.add 'hdo.count.questions.approved',         Question.approved.count
    g.add 'hdo.count.questions.pending',          Question.pending.count
    g.add 'hdo.count.questions.rejected',         Question.rejected.count
    g.add 'hdo.count.representatives.opted_out',  Representative.opted_out.count
    g.add 'hdo.count.representatives.registered', Representative.registered.count

    leaderboard = Hdo::Stats::Leaderboard.new(Issue.published)
    leaderboard.by_party.each do |party, counts|
      counts.each do |key, count|
        g.add "hdo.count.issues.#{party.slug}.#{key}", count
      end
    end
  end

  task :submit => %w[facebook stortinget holderdeord] do
    Hdo::Utils::GraphiteReporter.instance.submit
  end
end