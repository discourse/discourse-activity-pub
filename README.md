# Discourse ActivityPub Plugin

Allows you to publish Discourse posts via ActivityPub so they can be read on services that support ActivityPub such as Mastodon. For more information, please see https://meta.discourse.org/t/activitypub-plugin/266794

## Contributing

This section is about contributing to the plugin and assumes familiarity with Discourse plugin development. If you want to learn more about Discourse plugin development check out the guides on [meta.discourse.org](https://meta.discourse.org/t/developing-discourse-plugins-part-1-create-a-basic-plugin/30515).

### Server

Think about the plugin server as comprising three parts:

1. the AP module;
2. the plugin; and
3. Discourse integration.

#### The AP Module

The AP module:

- receives activities from external actors;
- manages a processing pipeline for activities; and
- sends activities to external actors.

As far as practicable this module should:

- be non-Discourse specific;
- reflect ActivityPub specifications; and
- reflect, and support common practices in the fediverse.

This focus allows for:

- clear separation of concerns;
- possible packaging of this functionality as a gem; and
- flexibility in how the plugin interacts with ActivityPub standards and practices.

#### The Plugin

Think of the "The Plugin" as comprising all of the non-AP classes (besides `discourse/discourse` extensions). These
classes:

- store and migrate ActivityPub data;
- establish relationships between the stored data;
- manage ActivityPub workers (jobs);
- perform specific ActivityPub functions, e.g. handlers, parsers, trackers and validators; and
- provide a backend for the ActivityPub functionality in the Discourse client.

As far as possible these classes should not *directly* integrate with `discourse/discourse`, even if they are Discourse-specific in their functionality. This separation aids in maintainability and extensibility. Over time some of the plugin classes may become generic `AP` classes, e.g. `lib/request.rb`, and some may become part of `discourse/discourse`, e.g. `lib/username_validator.rb`.

#### Discourse Integration

All direct `discourse/discourse` server integration is in the `plugin.rb` and the `/extensions`. Ideally, all `/extensions` will become integrations in the `plugin.rb` as `discourse/discourse` implements new server-side hooks and plugin methods. Some specific `discourse/discourse` updates to improve integration are suggested in `TODO` comments throughout the plugin code.

### Tests

When writing tests there's a few things to keep in mind:

1. The plugin has a few different interconnected states which sometimes need to be tested separately:
   - Plugin: enabled / disabled
   - Actor (i.e. Category): enabled / disabled
   - Publishing (i.e. login required): enabled / disabled
   - Publication type: first post / full topic

2. When testing code involving external requests use and extend the helper functions in `spec/plugin_helper.rb`.

3. When adding attributes to a `discourse/discourse` serializer make sure that serializer is covered by sql query count tests.

### Domains

If the environment variable `RAILS_DEVELOPMENT_HOSTS` is set the plugin will use the first domain in the variable as the local domain for the purposes of ActivityPub. For example, if you run Discourse like so

```
RAILS_DEVELOPMENT_HOSTS=discourse.ngrok.io bin/rails s
```

You will be able to use ActivityPub category handles on remote ActivityPub servers like so

```
announcements@discourse.ngrok.io
```

### Logging

When running in a Development environment the plugin's logger (`DiscourseActivityPub::Logger`) will log all ActivityPub messages with both the Rails logger *and* the AP Logger, which is set to log to `discourse/discourse/logs/activity_pub.log`. The AP logger will also log all incoming and outgoing ActivityPub objects in that dedicated file (formatted as yaml to make them easier to read).

### Delivery

Use the env variable `DISCOURSE_ACTIVITY_PUB_DELIVERY_DELAY` to manually override the delivery delay of ActivityPub objects, e.g.

```
DISCOURSE_ACTIVITY_PUB_DELIVERY_DELAY=0
```

### Multiple Local Instances

When testing Discourse to Discourse federation you may need to run multiple instances of Discourse locally. This will be an environment-specific question. One way of doing this is cloning two separate versions of `discourse/discourse` and using directory-specific environment variables (e.g. [direnv](https://direnv.net/) on a Mac) to manage the ports and database connections. A `.env` configuration that has worked is:

`~/discourse/discourse`

```
DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE=1
RAILS_DEVELOPMENT_HOSTS=discourse.ngrok.io
ALLOW_EMBER_CLI_PROXY_BYPASS=1
DISCOURSE_DEV_DB=discourse_development
DISCOURSE_DEV_LOG_LEVEL=debug
LOAD_PLUGINS=1
DISCOURSE_ACTIVITY_PUB_DELIVERY_DELAY=0
OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

`~/discourse/discourse_two`

```
DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE=1
RAILS_DEVELOPMENT_HOSTS=discourse-two.ngrok.io
ALLOW_EMBER_CLI_PROXY_BYPASS=1
DISCOURSE_DEV_DB=discourse_development_two
UNICORN_PORT=6000
PORT=6200
REDIS_PORT=6380
DISCOURSE_REDIS_PORT=6380
DISCOURSE_DEV_LOG_LEVEL=debug
LOAD_PLUGINS=1
DISCOURSE_ACTIVITY_PUB_DELIVERY_DELAY=0
OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```
