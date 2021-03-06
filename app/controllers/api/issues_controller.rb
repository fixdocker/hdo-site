module Api
  class IssuesController < ApiController
    before_filter :fetch_issue, except: :index

    def index
      respond_with Issue.
                    published.
                    order(:title).
                    page(params[:page] || 1).per(10)
    end

    def show
      respond_with @issue
    rescue ActiveRecord::RecordNotFound
      render json: {message: "could not find issue with id=#{params[:id]}"}, status: :not_found
    end

    def promises
      rel = @issue.promises.page(params[:page] || 1)

      respond_with rel, represent_with: PromisesRepresenter, issue: @issue
    end

    def timeline
      rel = @issue.proposition_connections.includes(:proposition => :votes).page(params[:page] || 1)

      respond_with rel, represent_with: PropositionConnectionsRepresenter, issue: @issue
    end

    private

    def fetch_issue
      @issue = Issue.published.find(params[:id])
    end
  end
end
