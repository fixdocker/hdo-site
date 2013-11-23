class Admin::IssuesController < AdminController
  before_filter :authorize_edit, except: :index
  before_filter :fetch_issue, only: [:show, :edit, :update, :destroy, :votes_search]
  before_filter :require_edit, except: [:index, :show]

  helper_method :edit_steps

  def index
    issues = Issue.order('frontpage IS FALSE, title').includes(:tags, :editor, :last_updated_by)
    @issues_by_status = issues.group_by { |e| e.status }

    respond_to do |format|
      format.html
      format.json { render json: @issues_by_status.values.flatten }
    end
  end

  def show
    xhr_only {
      @parties             = Party.order(:name)
      @accountability      = @issue.accountability
      @promise_connections = @issue.promise_connections.includes(promise: :promisor)

      render layout: false
    }
  end

  def new
    @issue = Issue.new

    fetch_categories
    edit_steps.first!
  end

  def edit
    if edit_steps.from_param
      assign_disable_buttons
      assign_issue_steps

      step = edit_steps.from_param!
      send "edit_#{step}"
    else
      redirect_to edit_step_admin_issue_path(@issue.id, step: edit_steps.first)
    end
  end

  def create
    @issue = Issue.new(params[:issue])
    @issue.last_updated_by = current_user

    if @issue.save
      PageCache.expire_issue(@issue)

      if edit_steps.finish?
        redirect_to @issue
      else
        redirect_to edit_step_admin_issue_path(@issue.id, step: edit_steps.after)
      end
    else
      logger.warn "failed to create issue: #{@issue.inspect}: #{@issue.errors.full_messages}"

      flash.alert = @issue.errors.full_messages.to_sentence
      fetch_categories
      edit_steps.first!

      render action: :new
    end
  end

  def update
    logger.info "updating issue: #{params.inspect}"
    update_ok = Hdo::IssueUpdater.new(@issue, params, current_user).update

    if update_ok
      if edit_steps.finish?
        edit_steps.clear!
        PageCache.expire_issue(@issue)
        # make sure we don't render a cached version to the editor
        redirect_to issue_path(@issue, lv: @issue.lock_version)
      else
        edit_steps.next!
        redirect_to edit_step_admin_issue_path(@issue.id, step: edit_steps.current)
      end
    else
      logger.warn "failed to update issue: #{@issue.inspect}: #{@issue.errors.full_messages}"

      flash.alert = @issue.errors.full_messages.to_sentence
      redirect_to edit_step_admin_issue_path(@issue.id, step: edit_steps.current)
    end
  end

  def destroy
    @issue.destroy
    redirect_to admin_issues_url
  end

  def votes_search
    votes = Vote.admin_search(
      params[:filter],
      params[:keyword],
      @issue.categories
    )

    # remove already connected votes
    votes -= @issue.vote_connections.map { |e| e.vote }

    # TODO: cleanup
    by_issue_type = Hash.new { |hash, issue_type| hash[issue_type] = Set.new }
    votes.each do |vote|
      vote.parliament_issues.each do |issue|
        by_issue_type[issue.issue_type] << vote
      end
    end

    render partial: 'votes_search_result', locals: { votes_by_issue_type: by_issue_type }
  end

  private

  def edit_categories
    fetch_categories
  end

  def edit_promises
    @promises_by_party = @issue.categories.includes(promises: [:promise_connections, :promisor, :parliament_period]).
                                           map(&:promises).compact.flatten.uniq.
                                           group_by { |e| e.short_party_names }.
                                           sort_by { |names, _| names }
  end

  def edit_party_comments
    @party_comments = PartyComment.find_all_by_issue_id(@issue)
  end

  def edit_positions
    @positions = Position.order(:priority).find_all_by_issue_id(@issue)
  end

  def edit_propositions
    @propositions_and_connections = @issue.proposition_connections.map { |e| [e.proposition, e] }
  end

  def edit_steps
    @edit_steps ||= Hdo::IssueEditSteps.new(params, session)
  end

  def authorize_edit
    unless policy(@issue || Issue.new).edit?
      flash.alert = t('app.errors.unauthorized')
      redirect_to admin_root_path
    end
  end

  def assign_issue_steps
    @issue_steps = Hdo::IssueEditSteps::STEPS
  end

  def assign_disable_buttons
    @disable_next = edit_steps.last?(params[:step]) or @issue && @issue.new_record?
    @disable_prev = edit_steps.first?(params[:step])
  end

  def fetch_categories
    @categories = Category.column_groups 4
  end

  def fetch_issue
    @issue = Issue.find(params[:id])
  end
end
