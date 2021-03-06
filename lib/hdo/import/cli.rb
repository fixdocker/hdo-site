# encoding: utf-8

require 'optparse'
require 'set'
require 'open-uri'
require 'fileutils'

module Hdo
  module Import
    class CLI
      AGREEMENT_CONFIG = {
        unit: :propositions,
        ignore_unanimous: true
      }

      attr_reader :options

      def initialize(argv)
        if argv.empty?
          raise ArgumentError, 'no args'
        else
          @options = parse_options argv
          @cmd     = argv.shift
          @rest    = argv
        end
      end

      def run
        case @cmd
        when 'json'
          import_files
        when 'daily'
          import_daily
        when 'api'
          import_api
        when 'dev'
          import_api(30)
        when 'representatives'
          import_api_representatives
        when 'votes'
          import_api_votes
        when 'parties'
          import_parties
        when 'promises'
          import_promises
        when 'parliament-issues', 'parliament-issues'
          import_parliament_issues
        when 'representative-emails'
          import_representative_emails
        when 'parliament-periods', 'parliament-sessions'
          import_parliament_periods
          import_parliament_sessions
        when 'wikidata'
          import_wikidata
        when 'agreement-stats'
          generate_agreement_stats
        when 'agreement-for-category'
          generate_agreement_for_category
        when 'rebel-stats'
          generate_rebel_stats
        when 'stats'
          generate_agreement_stats
          generate_rebel_stats
        else
          raise ArgumentError, "unknown command: #{@cmd.inspect}"
        end
      end

      private

      def import_parliament_issues
        parliament_issues = parsing_data_source.parliament_issues(@options[:session])
        persister.import_parliament_issues parliament_issues
      end

      def import_parties
        persister.import_parties parsing_data_source.parties(@options[:session])
      end

      def import_api(vote_limit = nil)
        persister.import_parliament_periods parsing_data_source.parliament_periods
        persister.import_parliament_sessions parsing_data_source.parliament_sessions
        persister.import_parties parsing_data_source.parties(@options[:session])
        persister.import_committees parsing_data_source.committees(@options[:session])
        persister.import_districts parsing_data_source.districts
        persister.import_categories parsing_data_source.categories

        import_api_representatives
        import_api_votes(vote_limit)
      end

      def import_parliament_periods
        persister.import_parliament_periods parsing_data_source.parliament_periods
      end

      def import_parliament_sessions
        persister.import_parliament_sessions parsing_data_source.parliament_sessions
      end

      def import_daily
        persister.import_parties parsing_data_source.parties(@options[:session])
        persister.import_committees parsing_data_source.committees(@options[:session])
        persister.import_districts parsing_data_source.districts
        persister.import_categories parsing_data_source.categories
        persister.import_parliament_periods parsing_data_source.parliament_periods
        persister.import_parliament_sessions parsing_data_source.parliament_sessions

        import_api_representatives

        parliament_issues = parsing_data_source.parliament_issues(@options[:session])

        each_parliament_issue(parliament_issues) do |parliament_issue, parliament_issue_details, votes|
          persister.import_parliament_issue parliament_issue, parliament_issue_details
          persister.import_votes votes, infer: false
        end

        # import_wikidata

        persister.infer_current_session

        if Rails.env.production?
          notify_new_votes
          notify_missing_emails
        end
      rescue Hdo::StortingImporter::DataSource::ServerError
        notify_api_error if Rails.env.production?
        raise
      end

      def import_api_votes(vote_limit = nil)
        parliament_issues = parsing_data_source.parliament_issues(@options[:session])

        if @options[:parliament_issue_ids]
          parliament_issues = parliament_issues.select { |i| @options[:parliament_issue_ids].include? i.external_id }
        end

        each_parliament_issue(parliament_issues, vote_limit) do |parliament_issue, parliament_issue_details, votes|
          persister.import_parliament_issue parliament_issue, parliament_issue_details
          persister.import_votes votes, infer: false
        end

        persister.infer_all_votes
      end

      def import_api_representatives
        representatives = {}
        representatives_today = []

        # the information in 'representatives_today' is more complete,
        # so it takes precedence
        if @options[:period] == ParliamentPeriod.current.name
          representatives_today = parsing_data_source.representatives_today

          representatives_today.each do |rep|
            representatives[rep.external_id] = rep
          end
        end

        parsing_data_source.representatives(@options[:period]).each do |rep|
          representatives[rep.external_id] ||= rep
        end

        persister.import_representatives representatives.values

        # mark currently attending representatives
        # see https://github.com/holderdeord/hdo-site/issues/195
        attending_xids = []
        substitute_xids = []

        representatives_today.map do |r|
          if r.substitute
            attending_xids << r.substitute
            substitute_xids << r.substitute
          else
            attending_xids << r.external_id
          end
        end

        Representative.all.each do |rep|
          xid = rep.external_id

          rep.update_attributes!(
            attending: attending_xids.include?(xid),
            substitute: substitute_xids.include?(xid)
          )
        end

        missing_reps = representatives_without_email.map(&:full_name)
        log.warn "representatives missing emails: #{missing_reps.to_json}" if missing_reps.any?
      end

      def import_promises
        spreadsheet = @rest.first or raise "no spreadsheet path given"

        promises = Hdo::StortingImporter::Promise.from_xlsx(spreadsheet)
        persister.import_promises promises
      end

      def import_wikidata
        key = ENV['MORPH_IO_API_KEY'] || return
        Wikidata.new(api_key: key, log: log).import
      end

      def generate_agreement_for_category
        category_name = ENV['CATEGORY_NAME'] || abort('must set CATEGORY_NAME')

        pis_by_session = Category.where(name: category_name).first.parliament_issues.group_by { |pi| pi.parliament_session_name }

        result = {}

        pis_by_session.to_a.each do |session_name, pis|
          votes = pis.flat_map(&:votes).uniq

          result[session_name] = Hdo::Stats::AgreementScorer.new(
            {votes: votes}.merge(AGREEMENT_CONFIG.dup)
          ).result
        end

        STDOUT << CSV.generate(col_sep: "\t") do |csv|
          sessions = result.keys.sort;
          combos = result.values.flat_map { |e| e.keys }.sort.uniq

          csv << ['', *sessions]

          combos.each do |combo|
            data = sessions.map do |s|
              d = result[s][combo]
              count = d[:count]
              total = d[:total]

              if count == 0 && total == 0
                0
              else
                (count * 100) / total.to_f
              end
            end

            csv << [combo, *data]
          end
        end
      end

      def generate_agreement_stats
        all_categories = !!ENV['ALL_CATEGORIES']
        exclude_budget = !!ENV['EXCLUDE_BUDGET']

        sessions     = ParliamentSession.where('start_date > ?', Time.parse('2009-08-31')).order(:start_date).to_a
        periods      = ParliamentPeriod.where('start_date > ?', Time.parse('2009-08-31')).order(:start_date).to_a
        categories   = all_categories ? Category.all : Category.where(main: true)
        category_key = all_categories ? 'categories-main' : 'categories-all'
        short_expiry = 1.day
        long_expiry  = 30.days
        budget_key   = "budget=#{!exclude_budget}"

        result = {
          by_session: Hash.new { |hash, key| hash[key] = {all: {}, categories: {}} },
          by_period: Hash.new { |hash, key| hash[key] = {all: {}, categories: {}} },
          all_time: {all: {}, categories: {}},
          current_session: ParliamentSession.current.name,
          current_period: ParliamentPeriod.current.name,
          last_update: Time.now,
          categories: categories.map(&:human_name)
        }

        config = AGREEMENT_CONFIG.dup
        config.merge!({exclude_issue_types: ['budsjett']}) if exclude_budget

        ranges = sessions + periods
        # ranges = periods

        ranges.each do |range|
          log.info "calculating agreement for #{range.name}"
          key = range.kind_of?(ParliamentSession) ? :by_session : :by_period

          expires_in = range.current? ? short_expiry : long_expiry

          result[key][range.name][:all] =
            Rails.cache.fetch("agreement/#{key}/#{range.name}/#{budget_key}/all", expires_in: expires_in) do
              Hdo::Stats::AgreementScorer.new({votes: range.votes}.merge(config)).result
            end

          category_to_votes = Hash.new { |hash, k| hash[k] = [] }

          range.votes.each do |vote|
            vote.categories.each do |cat|
              if all_categories
                category_to_votes[cat.human_name] << vote
                category_to_votes[cat.parent.human_name] << vote unless cat.main?
              else
                cat = cat.main? ? cat : cat.parent
                category_to_votes[cat.human_name] << vote
              end
            end
          end

          category_to_votes.each do |category_name, category_votes|
            result[key][range.name][:categories][category_name] =
              Rails.cache.fetch("agreement/#{key}/#{range.name}/#{budget_key}/#{category_key}/#{category_name}", expires_in: expires_in) do
                Hdo::Stats::AgreementScorer.new({votes: category_votes.uniq}.merge(config)).result
              end
          end

          GC.start
        end

        log.info "calculating agreement for all time"
        result[:all_time][:all] = Rails.cache.fetch("agreement/all_time/#{budget_key}/all", expires_in: short_expiry) do
          Hdo::Stats::AgreementScorer.new(config).result
        end

        GC.start

        categories.each do |category|
          result[:all_time][:categories][category.human_name] =
            Rails.cache.fetch("agreement/all_time/#{budget_key}/#{category_key}/#{category.human_name}", expires_in: short_expiry) do
              votes = category.votes + category.children.flat_map(&:votes)

              Hdo::Stats::AgreementScorer.new(
                {votes: votes.uniq}.merge(config)
              ).result
            end
        end

        filename_parts = ['agreement']
        filename_parts << 'all-categories' if all_categories
        filename_parts << 'no-budget' if exclude_budget

        filename = "#{filename_parts.join('-')}.json"

        FileUtils.mkdir_p('public/data')
        File.open("public/data/#{filename}", 'w') { |io| io << result.to_json }
      end

      def generate_rebel_stats
        # votes = Vote.where('time > ?', 12.months.ago)
        votes = Vote.all

        result = Hdo::Stats::Rebels.stats_for(votes)
        File.open('public/data/rebels.json', 'w') { |io| io << result.to_json }
      end

      def error_code_for(server_error_body)
        return Nokogiri::XML(e.body).css('//feilkode').text
      rescue
        nil
      end

      def each_parliament_issue(parliament_issues, limit = nil)
        count = 0

        parliament_issues.each_with_index do |parliament_issue, index|
          details = parsing_data_source.parliament_issue_details(parliament_issue.external_id)
          votes = []

          begin
            votes = parsing_data_source.votes_for(parliament_issue.external_id)
          rescue Hdo::StortingImporter::DataSource::ServerError => ex
            p ex.message
            # fra ME @ Stortinget
            ##### Grunnen til at du får en feilmelding på disse voteringene er at denne saken faktisk ikke har vedtak. Se merknad som er lagt ut på saken på nettsidene for nærmere forklaring på hvorfor dette skjer: https://www.stortinget.no/no/Saker-og-publikasjoner/Saker/Sak/Voteringsoversikt/?p=72682&dnid=1
            ##### Hvordan vi kan og skal håndtere disse sakene har vi ikke noe klart svar på akkurat nå. Det krever eventuelt endringer i underliggende systemer som vi ikke får gjort nå.
            ##### Den eneste løsningen jeg kan tilby nå er at man behandler feilkode 0 som at det ikke foreligger noe vedtak til voteringen.
            raise ex unless (ex.code == 500 || error_code_for(e.body) == "0")
          end

          count += votes.size

          yield parliament_issue, details, votes
          break if limit && count >= limit

          parliament_issue_count = index + 1
          remaining_parliament_issues = parliament_issues.size - parliament_issue_count
          remaining_votes = (count / parliament_issue_count.to_f) * remaining_parliament_issues

          log.info "->        #{count} votes for #{parliament_issue_count} parliament issues imported"
          log.info "->        about #{remaining_votes.to_i} votes remaining for #{remaining_parliament_issues} parliament issues"
        end
      end

      def import_files
        @rest.each do |file|
          print "\nimporting #{file}:"

          if file == "-"
            str = STDIN.read
          else
            str = open(file) { |io| io.read }
          end

          data = MultiJson.decode(str)

          data = case data
                 when Array
                   data
                 when Hash
                   [data]
                 else
                   raise TypeError, "expected Hash or Array, got: #{data.inspect}"
                 end

          import_data data
        end
      end

      def import_data(data)
        kinds = data.group_by do |hash|
          hash['kind'] or raise ArgumentError, "missing 'kind' property: #{hash.inspect}"
        end

        kinds.each do |kind, hashes|
          case kind
          when 'hdo#representative'
            persister.import_representatives hashes.map { |e| StortingImporter::Representative.from_hash(e) }
          when 'hdo#party'
            persister.import_parties hashes.map { |e| StortingImporter::Party.from_hash(e) }
          when 'hdo#committee'
            persister.import_committees hashes.map { |e| StortingImporter::Committee.from_hash(e) }
          when 'hdo#category'
            persister.import_categories hashes.map { |e| StortingImporter::Categories.from_hash(e) }
          when 'hdo#district'
            persister.import_districts hashes.map { |e| StortingImporter::District.from_hash(e) }
          when 'hdo#issue'
            persister.import_parliament_issues hashes.map { |e| StortingImporter::ParliamentIssue.from_hash(e) }
          when 'hdo#vote'
            # import_votes (plural) will also run VoteInferrer.
            persister.import_votes hashes.map { |e| StortingImporter::Vote.from_hash(e) }
          when 'hdo#promise'
            persister.import_promises hashes.map { |e| StortingImporter::Promise.from_hash(e) }
          else
            raise "unknown type: #{kind}"
          end
        end
      end

      def parsing_data_source
        @parsing_data_source ||= (
          ds = Hdo::StortingImporter::ParsingDataSource.new(api_data_source)

          case @options[:cache]
          when 'rails'
            Hdo::StortingImporter::CachingDataSource.new(ds, Rails.cache)
          when true
            Hdo::StortingImporter::CachingDataSource.new(ds)
          else
            ds
          end
        )
      end

      def api_data_source
        @api_data_source ||= Hdo::StortingImporter::ApiDataSource.default
      end

      def persister
        @persister ||= (
          persister = Persister.new
          persister.log = log

          persister
        )
      end

      def log
        @log ||= (
          if @options[:quiet]
            Logger.new(File::NULL)
          else
            Hdo::StortingImporter.logger
          end
        )
      end

      def notify_new_votes
        mail    = ImportMailer.votes_today_email
        return if mail.to.nil? # no new votes

        mail.deliver
        message = mail.parts.last.body.raw_source

        client = hipchat_client || return
        client['Holder de ord'].send('Stortinget', message.to_param, notify: true)
      rescue => ex
        log.error [ex.message, ex.backtrace].join("\n")
      end

      def notify_missing_emails
        client = hipchat_client || return
        missing = representatives_without_email

        return if missing.empty?

        template = <<-HTML
        <h2>Møtende representanter (ekslkudert varaer) uten epostadresse:</h2>
        <ul>
          <% missing.each do |rep| %>
          <li><%= rep.external_id %>: <%= rep.full_name %></li>
          <% end %>
        </ul>
        HTML

        message = ERB.new(template, 0, "%-<>").result(binding)
        client['Teknisk'].send('Stortinget', message, color: 'red', notify: true)
      rescue => ex
        log.error ex.message
      end

      def notify_api_error
        client = hipchat_client || return
        client['Teknisk'].send('API', "Feil hos data.stortinget.no! Hjelp!", color: 'red', notify: true)
      rescue => ex
        log.error ex.message
      end

      def representatives_without_email
        Representative.attending.where(email: nil, substitute: false)
      end

      def hipchat_client
        @hipchat_client ||= (
          token = AppConfig.hipchat_api_token
          HipChat::Client.new(token) unless token.blank?
        )
      end

      def parse_options(args)
        options = {
          :period  => ParliamentPeriod.current ? ParliamentPeriod.current.external_id : nil,
          :session => ParliamentSession.current ? ParliamentSession.current.external_id : nil
        }

        OptionParser.new { |opt|
          opt.on("-s", "--quiet") { @options[:quiet] = true }
          opt.on("--cache [rails]", "Cache results of API calls. Defaults to caching in memory, pass 'rails' to use Rails.cache instead.") do |arg|
            options[:cache] = arg || true
          end

          opt.on("--parliament-issues ISSUE_IDS", "Only import this comma-sparated list of issue external ids") do |ids|
            options[:parliament_issue_ids] = ids.split(",")
          end

          opt.on("--period PERIOD", %Q{The parliamentary period to import data for. Note that "today's representatives" will always be imported. Default: #{options[:period]}}) do |period|
            options[:period] = period
          end

          opt.on("--session SESSION", %Q{The parliamentary session to import data for. Note that "today's representatives" will always be imported. Default: #{options[:session]}}) do |session|
            options[:session] = session
          end

          opt.on("-h", "--help") do
            puts opt
            exit 1
          end
        }.parse!(args)

        options[:cache] ||= ENV['CACHE']

        options
      end

    end # CLI
  end # Import
end # Hdo
