# frozen_string_literal: true

module DiscourseActivityPub
  class UsernameSuggester
    LAST_RESORT_USERNAME = "actor"

    def self.suggest(username)
      username = normalize(username)
      username = normalize(I18n.t("fallback_username")) if username.blank?
      username = LAST_RESORT_USERNAME if username.blank?

      find_available(username)
    end

    def self.normalize(text)
      text.unicode_normalize(:nfkd).encode("ASCII", replace: "")
    end

    # Based on discourse/discourse/lib/user_name_suggester.rb#find_available_username_based_on
    def self.find_available(username)
      return username if DiscourseActivityPubActor.username_unique?(username)

      similar = "#{username}(0|1|2|3|4|5|6|7|8|9)+"
      count = DB.query_single(<<~SQL, like: "#{username}%", similar: similar).first
        SELECT count(*) FROM discourse_activity_pub_actors
        WHERE local IS TRUE
        AND username LIKE :like
        AND username SIMILAR TO :similar
      SQL

      offset =
        if count > 0
          params = { count: count + 10, username: username }
          available = DB.query_single(<<~SQL, params).first
          WITH numbers AS (SELECT generate_series(1, :count) AS n)
          SELECT n FROM numbers
          LEFT JOIN discourse_activity_pub_actors ON (
            username = :username || n::varchar
          ) AND (
            local IS TRUE
          )
          WHERE discourse_activity_pub_actors.id IS NULL
          ORDER by n ASC
          LIMIT 1
        SQL
          [available.to_i - 1, 0].max
        else
          0
        end

      i = 1
      attempt = username
      until (DiscourseActivityPubActor.username_unique?(attempt) || i > 100)
        suffix = (i + offset).to_s
        max_length = User.username_length.end - suffix.length
        attempt = "#{UserNameSuggester.truncate(username, max_length)}#{suffix}"
        i += 1
      end

      attempt
    end
  end
end
