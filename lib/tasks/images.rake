require 'net/http'
require 'uri'
require 'hdo/storting_importer'

namespace :images do
  task :locale do
    I18n.locale = :en # make sure we don't try to translate imagemagick errors
  end

  namespace :representatives do
    desc 'Reset representative images'
    task :reset => :environment do
      Representative.all.each { |e| e.image = nil; e.save! }
    end

    desc 'Fetch representatives images from stortinget.no'
    task :fetch => %w[environment locale] do
      api = Hdo::StortingImporter::ApiDataSource.default

      rep_image_path = Rails.root.join("tmp/downloads/representatives")
      rep_image_path.mkpath

      Representative.all.each do |rep|
        filename = rep_image_path.join("#{rep.slug}.jpg")

        if ENV['FORCE'].nil? && filename.exist?
          puts "skipping download for existing #{filename}, use FORCE=true to override"

          rep.image = filename.open
          rep.save!
        else
          begin
            photo = api.person_photo(
              rep.external_id,
              :large,
              true # fallback
            )

            File.open(filename.to_s, 'wb') { |io| io << photo }
            puts "saved #{rep.full_name} -> #{filename}"

            rep.image = filename.open
            rep.save!
          rescue Hdo::StortingImporter::DataSource::ServerError => ex
            raise unless ex.code == 404
            puts "WARN: unable to find image for #{rep.full_name}"
          end
        end
      end
    end
  end

  desc 'Save and scale party logos to Party models'
  task :party_logos => %w[environment locale] do
    path_to_logos = Rails.root.join("app/assets/images/party-logos-current")

    Party.all.each do |party|
      slug = party.slug == 'uav' ? 'unknown' : party.slug

      path = path_to_logos.join("#{slug}.png")

      if path.exist?
        party.logo = path.open
        party.save!
        puts "Logo for #{party.name} mapped as #{party.logo.url}."
      else
        raise "not found: #{path}"
      end
    end
  end


  TOPICS = {
    'Samferdsel'      => {ids: [251, 149, 212, 161, 257, 193, 200, 166, 259, 77, 6], image: "tema_samferdsel.jpg"},
    'Utdanning'       => {ids: [48, 262, 263, 52, 99, 4, 53, 145, 278, 227, 141, 47, 65, 231], image: "tema_utdanning.jpg"},
    'Klima og energi' => {ids: [270, 268, 186, 191, 57, 80, 236, 264, 8, 250, 195, 252, 266], image: "tema_klima.jpg"},
    'Helse og omsorg' => {ids: [143,197,169,18,146,123,246,198,145,175,303,237], image: "tema_helse.jpg"}
  }

  task :update_topic_issues => :environment do
    topic_ids = TOPICS.fetch(AppConfig.topic_of_the_week).fetch(:ids)

    Issue.published.each do |issue|
      issue.frontpage = topic_ids.include?(issue.id)

      if issue.changed?
        issue.last_updated_by = User.where(name: 'admin').first
      end

      issue.save!
    end
  end

  desc 'Fetch topic image'
  task :topic => :environment do
    image = TOPICS.fetch(AppConfig.topic_of_the_week).fetch(:image)

    ok = system "curl", "-s", "-o", Rails.root.join('public/images/topic.jpg').to_s, "http://files.holderdeord.no/images/#{image}"
    ok or raise "topic download failed"
  end

  desc 'Set up all images'
  task :all => %w[images:representatives:fetch images:party_logos images:topic]

  desc 'Reset and set up all images'
  task :reset => %w[representatives:reset all]
end
