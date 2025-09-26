import RouteTemplate from "ember-route-template";
import Navigation from "discourse/components/discovery/navigation";
import routeAction from "discourse/helpers/route-action";
import ActivityPubBanner from "../../components/activity-pub-banner";
import ActivityPubNav from "../../components/activity-pub-nav";

export default RouteTemplate(
  <template>
    <Navigation
      @createTopic={{@controller.createTopic}}
      @canCreateTopicOnTag={{@controller.canCreateTopicOnTag}}
      @category={{@controller.category}}
      @tag={{@controller.tag}}
    />

    {{#if @controller.site.activity_pub_publishing_enabled}}
      <ActivityPubBanner @actor={{@controller.actor}} />
    {{/if}}

    <ActivityPubNav
      @actor={{@controller.actor}}
      @follow={{routeAction "follow"}}
    />

    {{outlet}}
  </template>
);
