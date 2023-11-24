import Component from "@glimmer/component";
import NavItem from "discourse/components/nav-item";
import { inject as service } from "@ember/service";
import ActivityPubFollowBtn from "./activity-pub-follow-btn";

export default class ActivityPubCategoryNav extends Component {
  @service router;

  get showFollows() {
    return this.args.category.can_edit;
  }

  get onFollowsRoute() {
    return this.router.currentRouteName === "activityPub.category.follows";
  }

  get showCreateFollow() {
    return this.showFollows && this.onFollowsRoute;
  }

  <template>
    <div class="activity-pub-category-nav">
      <ul class="nav nav-pills">
        <NavItem
          @route="activityPub.category.followers"
          @label="discourse_activity_pub.category_nav.followers" />
        {{#if this.showFollows}}
          <NavItem
            @route="activityPub.category.follows"
            @label="discourse_activity_pub.category_nav.follows" />
        {{/if}}
      </ul>
      {{#if this.showCreateFollow}}
        <ActivityPubFollowBtn
          @actor={{@category.activity_pub_actor}}
          @follow={{@follow}} 
          @type="actor_follow" />
      {{/if}}
    </div>
  </template>
}
