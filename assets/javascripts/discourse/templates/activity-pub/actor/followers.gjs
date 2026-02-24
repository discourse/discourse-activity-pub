import { concat } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import ResponsiveTable from "discourse/components/responsive-table";
import TableHeaderToggle from "discourse/components/table-header-toggle";
import avatar from "discourse/helpers/avatar";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import ActivityPubActor from "../../../components/activity-pub-actor";
import ActivityPubFollowBtn from "../../../components/activity-pub-follow-btn";

export default RouteTemplate(
  <template>
    <LoadMore
      @selector=".directory-table .directory-table__cell"
      @action={{@controller.loadMore}}
      class="activity-pub-followers-container"
    >
      {{#if @controller.hasActors}}
        <ResponsiveTable @className={{@controller.tableClass}}>
          <:header>
            <TableHeaderToggle
              @field="actor"
              @labelKey="discourse_activity_pub.follow_table.actor"
              @automatic={{true}}
              @order={{@controller.order}}
              @asc={{@controller.asc}}
            />
            <TableHeaderToggle
              @field="user"
              @labelKey="discourse_activity_pub.follow_table.user"
              @automatic={{true}}
              @order={{@controller.order}}
              @asc={{@controller.asc}}
            />
            <TableHeaderToggle
              @field="followed_at"
              @labelKey="discourse_activity_pub.follow_table.followed_at"
              @automatic={{true}}
              @order={{@controller.order}}
              @asc={{@controller.asc}}
            />
            {{#if @controller.currentUser.admin}}
              <div
                class="directory-table__column-header activity-pub-follow-table-actions"
              >
                <span class="text">{{i18n
                    "discourse_activity_pub.follow_table.actions"
                  }}</span>
              </div>
            {{/if}}
          </:header>
          <:body>
            {{#each @controller.actors as |follower|}}
              <div class="directory-table__row activity-pub-follow-table-row">
                <div
                  class="directory-table__cell activity-pub-follow-table-actor"
                >
                  <ActivityPubActor @actor={{follower}} />
                </div>
                <div
                  class="directory-table__cell activity-pub-follow-table-user"
                >
                  {{#if follower.model}}
                    <a
                      class="avatar"
                      href={{concat "/u/" follower.model.username}}
                      data-user-card={{follower.model.username}}
                    >
                      {{avatar follower.model imageSize="small"}}
                    </a>
                  {{/if}}
                </div>
                <div
                  class="directory-table__cell activity-pub-follow-table-followed-at"
                >
                  {{ageWithTooltip follower.followed_at}}
                </div>
                {{#if @controller.currentUser.admin}}
                  <div
                    class="directory-table__cell activity-pub-follow-table-actions"
                  >
                    <ActivityPubFollowBtn
                      @actor={{@controller.actor}}
                      @follower={{follower}}
                      @reject={{routeAction "reject"}}
                      @type="actor_reject"
                    />
                  </div>
                {{/if}}
              </div>
            {{/each}}
          </:body>
        </ResponsiveTable>

        <ConditionalLoadingSpinner @condition={{@controller.loadingMore}} />
      {{else}}
        <p>{{i18n "search.no_results"}}</p>
      {{/if}}
    </LoadMore>
  </template>
);
