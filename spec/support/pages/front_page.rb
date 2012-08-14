module Pages
  class FrontPage < Page
    include HasMenu

    def initialize(driver, url)
      super(driver)

      @url = url
    end

    def load
      driver.navigate.to @url
    end

    def loaded?
      text =~ /Sjekk hva partiene har lovet og stemt/i
    end
  end
end