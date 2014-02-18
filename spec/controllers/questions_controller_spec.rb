require 'spec_helper'

describe QuestionsController do
  let(:representative) { Representative.make!(:attending, email: 'representative@example.com') }

  let(:valid_attributes) do
    { body: 'Tekst', representative: representative, from_name: 'Ola', from_email: 'ola@nordmann.no' }
  end

  describe "GET index" do
    it 'redirects to /questions/disabled' do
      get :index
      response.should redirect_to(disabled_questions_path)
    end

    xit "assigns unanswered questions as @questions[:unanswered]" do
      pending = Question.make!
      approved = Question.make!(status: 'approved')

      get :index
      assigns(:questions)[:unanswered].should eq([approved])
    end

    xit "ignores non-answered questions from our domain" do
      ours = Question.make!(from_email: 'test@holderdeord.no', status: 'approved')
      not_ours = Question.make!(from_email: 'test@example.com', status: 'approved')

      ours_with_approved_answer = Question.make!(from_email: 'test@holderdeord.no', status: 'approved')
      ours_with_approved_answer.create_answer!(body: 'test123', status: 'approved', representative: ours_with_approved_answer.representative)

      ours_with_pending_answer = Question.make!(from_email: 'test@holderdeord.no', status: 'approved')
      ours_with_pending_answer.create_answer!(body: 'test123', status: 'pending', representative: ours_with_pending_answer.representative)

      get :index
      assigns(:questions)[:unanswered].should eq([not_ours])
      assigns(:questions)[:answered].should eq([ours_with_approved_answer])
    end

    xit "assigns answered questions as @questions[:answered]" do
      q = Question.make! :approved
      a = Answer.make! question: q, status: 'approved'

      get :index
      assigns(:questions)[:answered].should eq([q])
    end

    xit "puts questions with pending answers in the unanswered bin" do
      q = Question.make! :approved
      a = Answer.make! question: q, status: 'pending'

      get :index
      assigns(:questions)[:unanswered].should eq [q]
    end

    xit 'assigns total question counts' do
      2.times { Question.make! :approved }
      3.times do
        q = Question.make! :approved
        Answer.make! question: q, status: 'approved'
      end

      get :index

      assigns(:totals)[:answered].should eq 3
      assigns(:totals)[:unanswered].should eq 2
    end
  end

  describe 'GET all' do
    xit 'assigns answered questions when /answered' do
      Question.make! :approved
      q = Question.make! :approved
      Answer.make! question: q, status: 'approved'

      get :all, category: 'answered'

      assigns(:questions).should eq [q]
    end

    xit 'assigns unanswered questions when /unanswered' do
      q1 = Question.make! :approved
      q2 = Question.make! :approved
      Answer.make! question: q1, status: 'approved'

      get :all, category: 'unanswered'

      assigns(:questions).should eq [q2]
    end

    xit 'hides unanswered questions from @hdo' do
      ours = Question.make!(from_email: 'test@holderdeord.no', status: 'approved')
      not_ours = Question.make!(from_email: 'test@example.com', status: 'approved')

      get :all, category: 'unanswered'

      assigns(:questions).should eq [not_ours]
    end

    xit 'shows 404 for unknown category' do
      get :all, category: 'goo'

      response.code.should eq '404'
    end
  end

  describe "GET show" do
    xit "assigns the requested question as @question" do
      question = Question.make!(status: 'approved', representative: Representative.make!(:confirmed))
      get :show, id: question.to_param

      assigns(:question).should eq(question)
      assigns(:answer).should be_nil
      assigns(:representative).should eq(question.representative)
      assigns(:party).should eq(question.representative.latest_party)
    end

    xit 'only finds approved questions' do
      expect {
        get :show, id: Question.make!(status: 'pending')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    xit 'assigns approved answers as @answer' do
      question = Question.make!(status: 'approved', representative: Representative.make!(:confirmed))
      question.create_answer!(body: 'foo', representative: question.representative, status: 'approved')

      get :show, id: question

      assigns(:answer).should == question.answer
      assigns(:representative).should == question.answer.representative
      assigns(:party).should eq(question.answer.representative.latest_party)
    end

    xit 'ignores non-approved answers' do
      question = Question.make!(status: 'approved')
      question.create_answer!(body: 'foo', representative: question.representative, status: 'pending')

      get :show, id: question

      assigns(:answer).should be_nil
    end
  end

  describe "GET new" do
    xit "assigns a new question as @question" do
      get :new
      assigns(:question).should be_a_new(Question)
    end

    xit "assigns the correct representative list" do
      attending_with_email     = Representative.make!(attending: true, email: 'a@stortinget.no')
      attending_without_email  = Representative.make!(attending: true, email: nil)
      not_attending_with_email = Representative.make!(attending: false, email: 'b@stortinget.no')

      get :new

      assigns(:representatives).should == [attending_with_email]
    end

    xit "redirects if read_only" do
      AppConfig.any_instance.stub(:read_only).and_return(true)
      get :new
      response.code.should eq '307'
    end
  end

  describe "POST create" do
    xit "redirects if read_only" do
      AppConfig.any_instance.stub(:read_only).and_return(true)
      post :create
      response.code.should eq '307'
    end

    describe "with valid params" do
      xit "creates a new Question" do
        expect {
          post :create, question: valid_attributes
        }.to change(Question, :count).by(1)
      end

      xit "assigns a newly created question as @question" do
        post :create, question: valid_attributes
        assigns(:question).should be_a(Question)
        assigns(:question).should be_persisted
      end

      xit "redirects to the created question" do
        post :create, question: valid_attributes
        response.should have_rendered(:create)
      end

      xit 'does not accepts a blank from_name' do
        post :create, question: valid_attributes.merge(from_name: '')

        q = assigns(:question)
        q.should_not be_valid

        response.should have_rendered(:new)
      end

      xit 'does not accept a blank from_email' do
        post :create, question: valid_attributes.merge(from_email: '')

        q = assigns(:question)
        q.should_not be_valid

        response.should have_rendered(:new)
      end
    end

    describe "with invalid params" do
      xit "assigns a newly created but unsaved question as @question" do
        # Trigger the behavior that occurs when invalid params are submitted
        Question.any_instance.stub(:save).and_return(false)
        post :create, {question: {  }}
        assigns(:question).should be_a_new(Question)
      end

      xit "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Question.any_instance.stub(:save).and_return(false)
        post :create, {question: {  }}

        assigns(:representatives).should_not be_nil
        assigns(:districts).should_not be_nil

        response.should render_template("new")
      end
    end
  end

  describe 'GET conduct' do
    xit 'renders the code of conduct' do
      get :conduct
      response.should have_rendered(:_conduct)
    end
  end
end
