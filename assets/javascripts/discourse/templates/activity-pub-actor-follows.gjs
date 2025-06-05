import { concat } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import ResponsiveTable from "discourse/components/responsive-table";
import TableHeaderToggle from "discourse/components/table-header-toggle";
import avatar from "discourse/helpers/avatar";
import boundDate from "discourse/helpers/bound-date";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import ActivityPubActor from "../components/activity-pub-actor";
import ActivityPubFollowBtn from "../components/activity-pub-follow-btn";

export default RouteTemplate(
  <template>
    <LoadMore
      @selector=".directory-table .directory-table__cell"
      @action={{@controller.loadMore}}
      class="activity-pub-follows-container"
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
            {{#if @controller.actor.can_admin}}
              <th
                class="activity-pub-follow-table-actions directory-table__column-header"
              ></th>
            {{/if}}
          </:header>
          <:body>
            {{#each @controller.actors as |actor|}}
              <div class="directory-table__row activity-pub-follow-table-row">
                <div
                  class="directory-table__cell activity-pub-follow-table-actor"
                >
                  <ActivityPubActor @actor={{actor}} />
                </div>
                <div
                  class="directory-table__cell activity-pub-follow-table-user"
                >
                  {{#if actor.model}}
                    <a
                      class="avatar"
                      href={{concat "/u/" actor.model.username}}
                      data-user-card={{actor.model.username}}
                    >
                      {{avatar actor.model imageSize="small"}}
                    </a>
                  {{/if}}
                </div>
                <div
                  class="directory-table__cell activity-pub-follow-table-followed-at"
                >
                  {{#if actor.followed_at}}
                    {{boundDate actor.followed_at}}
                  {{else}}
                    {{i18n
                      "discourse_activity_pub.follow_table.follow_pending"
                    }}
                  {{/if}}
                </div>
                {{#if @controller.actor.can_admin}}
                  <div
                    class="directory-table__cell activity-pub-follow-table-actions"
                  >
                    <ActivityPubFollowBtn
                      @actor={{@controller.actor}}
                      @followedActor={{actor}}
                      @unfollow={{routeAction "unfollow"}}
                      @type="actor_unfollow"
                    />
                  </div>
                {{/if}}
              </div>
            {{/each}}
          </:body>
        </ResponsiveTable>

        <ConditionalLoadingSpinner
          @condition={{@controller.model.loadingMore}}
        />
      {{else}}
        <p>{{i18n "search.no_results"}}</p>
      {{/if}}
    </LoadMore>
  </template>
);
