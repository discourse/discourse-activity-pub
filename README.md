# Discourse ActivityPub Plugin

Allows you to publish Discourse posts via ActivityPub so they can be read on services that support ActivityPub such as Mastodon.

For more information, please see https://meta.discourse.org/t/activitypub-plugin/266794

### Development

To make it easier to work with remote ActivityPub servers when developing if the environment variable `RAILS_DEVELOPMENT_HOSTS` is set the plugin will use the first domain in the variable (it's a comma separated list) as the local domain for the purposes of ActivityPub.

For example, if you run Discourse like so

```
RAILS_DEVELOPMENT_HOSTS=angus.eu.ngrok.io bin/rails s
```

You will be able to use ActivityPub category handles on remote ActivityPub servers like so

```
announcements@angus.eu.ngrok.io
```
