import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminNav from "admin/components/admin-nav";

export default RouteTemplate(
  <template>
    {{#AdminNav}}
      <li>
        <LinkTo
          @route="adminPlugins.activityPub.actor"
          @query={{hash model_type="category"}}
        >
          <span>{{i18n
              "admin.discourse_activity_pub.actor.category.label"
            }}</span>
        </LinkTo>
      </li>
      <li>
        <LinkTo
          @route="adminPlugins.activityPub.actor"
          @query={{hash model_type="tag"}}
        >
          <span>{{i18n "admin.discourse_activity_pub.actor.tag.label"}}</span>
        </LinkTo>
      </li>
      <li>
        <LinkTo @route="adminPlugins.activityPub.log">
          <span>{{i18n "admin.discourse_activity_pub.log.label"}}</span>
        </LinkTo>
      </li>
      <li class={{@controller.addActorClass}}>
        <LinkTo
          @route="adminPlugins.activityPub.actorShow"
          @model={{@controller.newActor}}
          @query={{hash model_type=@controller.model_type}}
        >
          {{icon "plus"}}
          <span>{{i18n @controller.addActorLabel}}</span>
        </LinkTo>
      </li>
    {{/AdminNav}}

    <div class="admin-container">
      {{outlet}}
    </div>
  </template>
);
