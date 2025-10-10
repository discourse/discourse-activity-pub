import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";
import ActivityPubActorCard from "../../components/activity-pub-actor-card";

export default RouteTemplate(
  <template>
    <div class="activity-pub-about">
      <h1>{{i18n "discourse_activity_pub.about.title"}}</h1>
      <p>{{i18n "discourse_activity_pub.about.description"}}</p>
      {{#if @controller.hasCategoryActors}}
        <div class="activity-pub-actors categories">
          <h3>{{i18n "discourse_activity_pub.about.categories"}}</h3>
          <div class="activity-pub-actors-list">
            {{#each @controller.categoryActors as |actor|}}
              <ActivityPubActorCard @actor={{actor}} />
            {{/each}}
          </div>
        </div>
      {{/if}}
      {{#if @controller.hasTagActors}}
        <div class="activity-pub-actors tags">
          <h3>{{i18n "discourse_activity_pub.about.tags"}}</h3>
          <div class="activity-pub-actors-list">
            {{#each @controller.tagActors as |actor|}}
              <ActivityPubActorCard @actor={{actor}} />
            {{/each}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
);
