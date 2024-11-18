import Component from "@glimmer/component";
import { service } from "@ember/service";
import NavItem from "discourse/components/nav-item";
import ActivityPubFollowBtn from "./activity-pub-follow-btn";

export default class ActivityPubNav extends Component {
  @service router;
  @service site;

  get showFollows() {
    return this.args.actor.can_admin;
  }

  get showFollowers() {
    return this.site.activity_pub_publishing_enabled;
  }

  get onFollowsRoute() {
    return this.router.currentRouteName === "activityPub.actor.follows";
  }

  get showCreateFollow() {
    return this.showFollows && this.onFollowsRoute;
  }

  <template>
    <div class="activity-pub-nav">
      <ul class="nav nav-pills">
        {{#if this.showFollowers}}
          <NavItem
            @route="activityPub.actor.followers"
            @label="discourse_activity_pub.discovery.followers"
          />
        {{/if}}
        {{#if this.showFollows}}
          <NavItem
            @route="activityPub.actor.follows"
            @label="discourse_activity_pub.discovery.follows"
          />
        {{/if}}
      </ul>
      {{#if this.showCreateFollow}}
        <ActivityPubFollowBtn
          @actor={{@actor}}
          @follow={{@follow}}
          @type="actor_follow"
        />
      {{/if}}
    </div>
  </template>
}
