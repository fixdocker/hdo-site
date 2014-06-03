require 'selenium-webdriver'
require 'loadable_component'

require_relative 'pages/waitable'
require_relative 'pages/page'
require_relative 'pages/menu'
require_relative 'pages/front_page'
require_relative 'pages/votes_page'
require_relative 'pages/admin_login_page'
require_relative 'pages/admin_issue_editor_page'

module BrowserSpecHelper
  extend self
  include Rails.application.routes.url_helpers

  def driver
    $spec_driver ||= Selenium::WebDriver.for :firefox
  end

  def stop
    $spec_driver.quit if $spec_driver
  end

  def app_url
    "http://#{host}:#{port}"
  end

  def wait(timeout = 3)
    Selenium::WebDriver::Wait.new(timeout: timeout)
  end

  def front_page
    @front_page ||= Pages::FrontPage.new(driver, app_url)
  end

  def admin_login_page
    @admin_login_page ||= Pages::AdminLoginPage.new(driver, URI.join(app_url, '/users/sign_in').to_s)
  end

  def refresh_indeces
    SearchSettings.models.each { |m| m.__elasticsearch__.refresh_index! }
  end

  def admin_issue_editor_page(id = :new)
    if id == :new
      path = new_admin_issue_path
    else
      path = admin_edit_issue_path(slug)
    end

    Pages::AdminIssueEditorPage.new(driver, URI.join(app_url, path).to_s)
  end

  def votes_page
    @votes_page ||= Pages::VotesPage.new(driver, front_page)
  end

  def host
    "127.0.0.1"
  end

  def start
    timeout = 15
    port_to_use = port()

    Thread.abort_on_exception = true

    $spec_app = Thread.new do
      Rack::Server.new(:app         => Hdo::Application,
                       :environment => Rails.env,
                       :Port        => port_to_use).start
    end

    sp = Selenium::WebDriver::SocketPoller.new(host, port, timeout)
    unless sp.connected?
      raise "could not launch app in #{timeout} seconds"
    end
  end

  def port
    $spec_port ||= Selenium::WebDriver::PortProber.above(3000)
  end
end
