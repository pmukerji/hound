class CommentingPolicy
  pattr_initialize :pull_request

  def allowed_for?(violation)
    tag = [
      violation.build.repo.full_github_name,
      violation.build.pull_request_number
    ].join("-")

    all_comments = violation.messages
    previous_comments = previous_comments_on_line(violation).map(&:body)

    Rails.logger.tagged("COMMENT_CHECK", tag) do
      Rails.logger.info "All: #{all_comments.inspect}"
      Rails.logger.info "Existing: #{previous_comments.inspect}"
    end

    unreported_violation_messages(violation).any?
  end

  private

  def unreported_violation_messages(violation)
    violation.messages - existing_violation_messages(violation)
  end

  def existing_violation_messages(violation)
    previous_comments_on_line(violation).map(&:body).
      flat_map { |body| body.split("<br>") }
  end

  def previous_comments_on_line(violation)
    existing_comments.select do |comment|
      comment.path == violation.filename &&
        comment.original_position == violation.patch_position
    end
  end

  def existing_comments
    @existing_comments ||= pull_request.comments
  end
end
