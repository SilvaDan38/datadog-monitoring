FROM ruby:3.3-alpine

RUN apk add --no-cache build-base postgresql-dev

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install --jobs 4 --retry 3

COPY . .

ENV DD_SERVICE=ruby-crud
ENV DD_ENV=docker
ENV DD_VERSION=1.0.0
ENV DD_LOGS_INJECTION=true
ENV DD_PROFILING_ENABLED=true
ENV DD_RUNTIME_METRICS_ENABLED=true
ENV DD_DBM_PROPAGATION_MODE=full
ENV DD_APPSEC_ENABLED=true

EXPOSE 4567

# auto_instrument já está no app.rb — não precisa do ddtracerb exec
CMD ["bundle", "exec", "ruby", "app.rb"]
