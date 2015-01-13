class RepoSynchronization
  ORGANIZATION_TYPE = 'Organization'

  pattr_initialize :user, :github_token
  attr_reader :user

  def api
    @api ||= GithubApi.new(github_token)
  end

  def start
    existing_repos = user.repos.to_a
    user.repos.clear

    api.repos.each do |resource|
      attributes = repo_attributes(resource.to_hash)
      repo = Repo.find_or_create_with(attributes)
      user.repos << repo
      existing_repos.delete(repo)
    end

    existing_repos.each do |repo|
      repo.deactivate

      if repo.subscription
        RepoSubscriber.unsubscribe(repo, user)
      end
    end
  end

  private

  def repo_attributes(attributes)
    {
      private: attributes[:private],
      github_id: attributes[:id],
      full_github_name: attributes[:full_name],
      in_organization: attributes[:owner][:type] == ORGANIZATION_TYPE
    }
  end
end
