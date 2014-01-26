namespace :search do
  desc 'Reindex'
  task :reindex => :environment do
    Hdo::Search::Settings.models.each do |klass|
      next if ENV['CLASS'] && ENV['CLASS'] != klass.to_s
      puts "\n#{klass}"

      elasticsearch = klass.__elasticsearch__

      elasticsearch.delete_index!
      ok = elasticsearch.create_index!['ok']
      ok or raise "unable to create #{index.name}, #{index.response && index.response.body}"

      klass = klass.published if klass == Issue

      indexed_count = 0
      total = klass.count

      klass.import { |response|
        count = response['items'].size
        took  = response['took']

        indexed_count += count
        puts "\t#{count.to_s.ljust(4)} (#{indexed_count}/#{total} in #{took}ms)"
      }
    end
  end

  desc 'Run a fake search server'
  task :fake do
    require 'rack'
    Rack::Server.new(app: lambda { |env| [200, {}, ["{}"]]}, :Port => 9200, :server => "thin").start
  end

  desc 'Download elasticsearch config from our Puppet repo'
  task :setup do
    require 'open-uri'

    dir = Rails.root.join('config/search')
    dir.mkpath

    %w[words.nb.txt synonyms.nb.txt].each do |file|
      dir.join(file).open("wb") do |dest|
        src = open("https://raw.github.com/holderdeord/hdo-puppet/master/modules/elasticsearch/files/config/hdo.#{file}")
        IO.copy_stream(src, dest)
      end
    end
  end
end