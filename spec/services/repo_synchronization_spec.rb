require 'spec_helper'

describe RepoSynchronization do
  describe '#start' do
    it 'saves privacy flag' do
      attributes = {
        full_name: 'user/newrepo',
        id: 456,
        private: true,
        owner: {
          type: 'User'
        }
      }
      resource = double(:resource, to_hash: attributes)
      api = double(:github_api, repos: [resource])
      allow(GithubApi).to receive(:new).and_return(api)
      user = create(:user)
      github_token = 'token'
      synchronization = RepoSynchronization.new(user, github_token)

      synchronization.start

      expect(user.repos.first).to be_private
    end

    it 'saves organization flag' do
      attributes = {
        full_name: 'user/newrepo',
        id: 456,
        private: false,
        owner: {
          type: 'Organization'
        }
      }
      resource = double(:resource, to_hash: attributes)
      api = double(:github_api, repos: [resource])
      allow(GithubApi).to receive(:new).and_return(api)
      user = create(:user)
      github_token = 'token'
      synchronization = RepoSynchronization.new(user, github_token)

      synchronization.start

      expect(user.repos.first).to be_in_organization
    end

    it 'replaces existing repos' do
      attributes = {
        full_name: 'user/newrepo',
        id: 456,
        private: false,
        owner: {
          type: 'User'
        }
      }
      resource = double(:resource, to_hash: attributes)
      github_token = 'token'
      membership = create(:membership)
      user = membership.user
      api = double(:github_api, repos: [resource])
      allow(GithubApi).to receive(:new).and_return(api)
      synchronization = RepoSynchronization.new(user, github_token)

      synchronization.start

      expect(GithubApi).to have_received(:new).with(github_token)
      expect(user.repos.size).to eq(1)
      expect(user.repos.first.full_github_name).to eq 'user/newrepo'
      expect(user.repos.first.github_id).to eq 456
    end

    it 'renames an existing repo if updated on github' do
      membership = create(:membership)
      repo_name = 'user/newrepo'
      attributes = {
        full_name: repo_name,
        id: membership.repo.github_id,
        private: true,
        owner: {
          type: 'User'
        }
      }
      resource = double(:resource, to_hash: attributes)
      github_token = 'githubtoken'

      api = double(:github_api, repos: [resource])
      allow(GithubApi).to receive(:new).and_return(api)
      synchronization = RepoSynchronization.new(membership.user, github_token)

      synchronization.start

      expect(membership.user.repos.first.full_github_name).to eq repo_name
      expect(membership.user.repos.first.github_id).
        to eq membership.repo.github_id
    end

    it "deactivates a repo if it was deleted from github" do
      repo = create(:repo, :active)
      membership = create(:membership, repo: repo)
      user = membership.user
      create(:subscription, user: user, repo: repo)
      ignored_repo = create(:repo, :active)
      create(:subscription, user: user, repo: ignored_repo)
      github_token = "githubtoken"
      api = double(:github_api, repos: [])
      allow(GithubApi).to receive(:new).and_return(api)
      allow(RepoSubscriber).to receive(:unsubscribe)
      synchronization = RepoSynchronization.new(user, github_token)

      synchronization.start
      repo.reload

      expect(repo).not_to be_active
      expect(RepoSubscriber).to have_received(:unsubscribe).with(repo, user)
      expect(ignored_repo).to be_active
    end

    describe 'when a repo membership already exists' do
      it 'creates another membership' do
        first_membership = create(:membership)
        repo = first_membership.repo
        attributes = {
          full_name: repo.full_github_name,
          id: repo.github_id,
          private: true,
          owner: {
            type: 'User'
          }
        }
        resource = double(:resource, to_hash: attributes)
        github_token = 'githubtoken'
        second_user = create(:user)
        api = double(:github_api, repos: [resource])
        allow(GithubApi).to receive(:new).and_return(api)
        synchronization = RepoSynchronization.new(second_user, github_token)

        synchronization.start

        expect(second_user.reload.repos.size).to eq(1)
      end
    end
  end
end
