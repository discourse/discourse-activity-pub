import { concat, fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import ResponsiveTable from "discourse/components/responsive-table";
import bodyClass from "discourse/helpers/body-class";
import { i18n } from "discourse-i18n";
import ActivityPubActor from "../../components/activity-pub-actor";
import ActivityPubAuthorize from "../../components/activity-pub-authorize";

export default RouteTemplate(
  <template>
    {{bodyClass "user-preferences-activity-pub-page"}}

    <div class="control-group user-actors">
      <label class="control-label">
        {{i18n "user.discourse_activity_pub.actors.title"}}
      </label>
      <div class="controls">
        <label>{{i18n "user.discourse_activity_pub.actors.description"}}</label>
        <ActivityPubAuthorize />
      </div>
    </div>

    {{#if @controller.hasAuthorizations}}
      <div class="activity-pub-authorizations">
        <ResponsiveTable @className="activity-pub-actor-table authorizations">
          <:header>
            <div
              class="activity-pub-actor-table-actor directory-table__column-header"
            >
              <div class="header-contents">
                {{i18n "user.discourse_activity_pub.actor"}}
              </div>
            </div>
            <div
              class="activity-pub-actor-table-auth-type directory-table__column-header"
            >
              <div class="header-contents">
                {{i18n "user.discourse_activity_pub.auth_type"}}
              </div>
            </div>
            <div
              class="activity-pub-actor-table-actions directory-table__column-header"
            >
              <div class="header-contents">
                {{i18n "user.discourse_activity_pub.actions"}}
              </div>
            </div>
          </:header>
          <:body>
            {{#each @controller.authorizations as |authorization|}}
              <div class="directory-table__row activity-pub-actor-table-row">
                <div
                  class="directory-table__cell activity-pub-actor-table-actor"
                >
                  <ActivityPubActor @actor={{authorization.actor}} />
                </div>
                <div
                  class="directory-table__cell activity-pub-actor-table-auth-type"
                >
                  {{i18n
                    (concat
                      "user.discourse_activity_pub.authorize.auth_type."
                      authorization.auth_type
                      ".title"
                    )
                  }}
                </div>
                <div
                  class="directory-table__cell activity-pub-actor-table-actions"
                >
                  <DButton
                    @icon="xmark"
                    @action={{fn @controller.remove authorization}}
                    @label="user.discourse_activity_pub.remove_authorization_button.label"
                    @title="user.discourse_activity_pub.remove_authorization_button.title"
                    id="user_activity_pub_authorize_remove_authorization"
                    class="activity-pub-authorize-remove-authorization"
                  />
                </div>
              </div>
            {{/each}}
          </:body>
        </ResponsiveTable>
      </div>
    {{/if}}
  </template>
);
