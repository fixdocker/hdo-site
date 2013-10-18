# encoding: UTF-8

class HomeController < ApplicationController
  hdo_caches_page :index,
                  :contact,
                  :join,
                  :support,
                  :people,
                  :about,
                  :member,
                  :robots,
                  :faq,
                  :friends,
                  :services,
                  :terms

  def index
    published = Issue.published.includes(:tags)

    @all_tags    = published.flat_map(&:tags).uniq.sort_by(&:name)
    @parties     = Party.order(:name)
    @issues      = published.for_frontpage(7).map { |e| e.decorate }
    @main_issue  = @issues.shift
    @questions   = Question.not_ours.with_approved_answers.order("answers.created_at").last(2).map(&:decorate)
    @leaderboard = Hdo::Stats::Leaderboard.new(published)

    if AppConfig.frontpage_blog_enabled
      @latest_posts = Hdo::Utils::BlogFetcher.last(2)
    end
  end

  def robots
    if Rails.env.production?
      robots = ''
    else
      robots = "User-Agent: *\nDisallow: /\n"
    end

    render text: robots, layout: false, content_type: "text/plain"
  end

  def about
  end

  def faq
  end

  def contact
  end

  def join
  end

  def support
  end

  def member
  end

  def friends
  end

  def revision
    rev = AppConfig['revision'] ||= (
      file = Rails.root.join('REVISION')
      file.exist? ? file.read : `git rev-parse HEAD`.strip
    )

    render text: rev, content_type: 'text/plain'
  end

  def healthz
    head :ok
  end

  def people
    @all_members = User.where(active: true).sort_by { |e| e.name.split(" ").last }
    @board = @all_members.select { |member| member.board? }

    @other = [
      Person.new("Alex Asensi"),
      Person.new("Arne Hassel"),
      Person.new("Bjørn Dyresen"),
      Person.new("Eli Foss"),
      Person.new("Kristofer Rees"),
      Person.new("Lotte Bredesen Simonsen"),
      Person.new("Petter Reinholdsen"),
      Person.new('Anders Berg Hansen'),
      Person.new('Anne Raaum Christensen'),
      Person.new('Carl Martin Rosenberg'),
      Person.new('Cathrine Berg-Nielsen'),
      Person.new('Cosimo Streppone'),
      Person.new('Daniel Kafkas'),
      Person.new('Dina Hestad'),
      Person.new('Einar Kjerschow'),
      Person.new('Einar Sundin'),
      Person.new('Eirik Swensen'),
      Person.new('Elida Høeg'),
      Person.new('Ellen M. E. Lundring'),
      Person.new('Endre Ottosen'),
      Person.new('Erik Seierstad'),
      Person.new('Esben Jensen'),
      Person.new('Frode Hiorth'),
      Person.new('Guro Øistensen'),
      Person.new('Inge Olav Fure'),
      Person.new('Ingrid Lomelde'),
      Person.new('Ingrid Ødegaard'),
      Person.new('Jan Olav Ryfetten'),
      Person.new('Joanna Merker'),
      Person.new('Jostein Holje'),
      Person.new('Kristian Bysheim'),
      Person.new('Kristiane Hammer'),
      Person.new('Linn Katrine Erstad'),
      Person.new('Liv Arntzen Løchen'),
      Person.new('Madeleine Skjelland Eriksen'),
      Person.new('Magnus Løseth'),
      Person.new('Marit Sjøvaag Marino'),
      Person.new('Markus Krüger'),
      Person.new('Marte Haabeth Grindaker'),
      Person.new('Martin Bekkelund'),
      Person.new('Nina Jensen'),
      Person.new('Ole Martin Volle'),
      Person.new('Osman Siddique'),
      Person.new('Rigmor Haga'),
      Person.new('Salve Nilsen'),
      Person.new('Sara Mjelva'),
      Person.new('Silje Nyløkken'),
      Person.new('Svein Halvor Halvorsen'),
      Person.new('Tage Augustson'),
      Person.new('Thomas Huang'),
      Person.new('Tommy Steinsli'),
      Person.new('Tor Håkon Inderberg'),
      Person.new('Vegar Heir'),
      Person.new('Vilde Grønn'),
      Person.new('Øystein Jerkø Kostøl'),
     ]
  end

  class Person
    attr_reader :name, :image, :email, :bio

    def initialize(name, email = nil, image = nil, bio = nil)
      @name, @email, @image, @bio = name, email, image, bio
    end
  end

end
