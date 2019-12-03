# frozen_string_literal: true

# name: discourse-logster-rate-limit-checker
# about: Add scheduled jobs to check the logster's rate limit.
# version: 0.0.1
# authors: Alan Tan (tgxworld)
# url: https://github.com/discourse/discourse-logster-rate-limit-checker

after_initialize do
  if (RailsMultisite::ConnectionManagement.current_db == RailsMultisite::ConnectionManagement::DEFAULT)
    module ::LogsterRateLimitChecker
      STORE = Logster.store
      RATE_LIMITS = STORE.rate_limits[RailsMultisite::ConnectionManagement::DEFAULT]
      RATE_LIMIT_KEY_PREFIX = "__DEV_RATE_LIMIT_KEY__"

      if (RATE_LIMITS && !RATE_LIMITS.empty?)
        RATE_LIMITS.each do |rate_limiter|
          Discourse.redis.set("#{RATE_LIMIT_KEY_PREFIX}:#{rate_limiter.duration}", rate_limiter.key)
        end

        def self.check_rate_limits(duration, limit)
          RATE_LIMITS.each do |rate_limiter|
            next if (duration != rate_limiter.duration) || !(callback = rate_limiter.callback)
            rate = rate_limiter.retrieve_rate
            callback.call(rate) if rate > limit
          end
        end

        class PerMinuteChecker < ::Jobs::Scheduled
          every 10.seconds

          def execute(args)
            ::LogsterRateLimitChecker.check_rate_limits(
              60, SiteSetting.alert_admins_if_errors_per_minute
            )
          end
        end

        class PerHourChecker < ::Jobs::Scheduled
          every 10.minute

          def execute(args)
            ::LogsterRateLimitChecker.check_rate_limits(
              3600, SiteSetting.alert_admins_if_errors_per_hour
            )
          end
        end
      end
    end
  end
end
