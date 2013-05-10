class QuestionsController < ApplicationController
  before_filter { assert_feature(:questions) }

  def index
    @questions = Question.approved
  end

  def show
    @question = Question.approved.find(params[:id])
  end

  def new
    fetch_representatives_and_districts
    @question = Question.new
  end

  def create
    question = normalize_blanks(params[:question])
    rep      = question.delete(:representative)

    @question = Question.new(question)
    @question.representative = Representative.find_by_slug(rep) if rep

    unless @question.save
      fetch_representatives_and_districts
      render action: "new"
    end
  end

  private

  def fetch_representatives_and_districts
    @representatives=  Rails.cache.fetch('question-form/representatives', expires_in: 1.day) do
      Representative.includes(:district, party_memberships: :party).order(:last_name).to_a
    end

    @districts = Rails.cache.fetch('question-form/districts') do
      District.order(:name).to_a
    end
  end
end
