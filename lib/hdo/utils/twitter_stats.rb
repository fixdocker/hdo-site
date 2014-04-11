module Hdo
  module Utils
    class TwitterStats
      def initialize(opts = {})
        @client = Twitter::REST::Client.new({
          consumer_key: ENV['TWITTER_CONSUMER_KEY'],
          consumer_secret: ENV['TWITTER_CONSUMER_SECRET'],
        }.merge(opts))

        @data = {}
      end

      def display
        stats.each { |k, v| puts "#{k}: #{v}" }
      end

      def stats
        data = @data

        usernames = {'holderdeord' => 'holderdeord'}

        representatives = Representative.with_twitter
        representatives.each do |rep|
          usernames[rep.twitter_id] = rep.slug
        end

        usernames.keys.sort.each_slice(50) do |slice|
          @client.users(slice).each do |user|
            slug = usernames[user.screen_name] || next

            data["twitter.#{slug}.followers"] = user.followers_count
            data["twitter.#{slug}.following"] = user.friends_count
            data["twitter.#{slug}.tweets"]    = user.tweets_count
          end
        end

        data
      end
    end
  end
end