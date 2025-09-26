import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import ResponsiveTable from "discourse/components/responsive-table";
import TableHeaderToggle from "discourse/components/table-header-toggle";
import { i18n } from "discourse-i18n";
import ActivityPubActorAdminRow from "../../../components/activity-pub-actor-admin-row";

export default RouteTemplate(
  <template>
    <div class="admin-title activity-pub-actor-title">
      <h2>{{@controller.title}}</h2>
    </div>

    <LoadMore
      @selector=".directory-table .directory-table__cell"
      @action={{@controller.loadMore}}
      class="activity-pub-actors-container"
    >
      {{#if @controller.hasActors}}
        <ResponsiveTable @className="activity-pub-actor-table">
          <:header>
            <TableHeaderToggle
              @field="actor"
              @labelKey="admin.discourse_activity_pub.actor.table.actor"
              @automatic={{true}}
              @order={{@controller.order}}
              @asc={{@controller.asc}}
            />
            <TableHeaderToggle
              @field="model"
              @labelKey="admin.discourse_activity_pub.actor.table.model"
              @automatic={{true}}
              @order={{@controller.order}}
              @asc={{@controller.asc}}
              class="activity-pub-actor-table-model"
            />
            <div
              class="activity-pub-actor-table-status directory-table__column-header"
            >
              <div class="header-contents">
                {{i18n "admin.discourse_activity_pub.actor.table.status"}}
              </div>
            </div>
            <div
              class="activity-pub-actor-table-actions directory-table__column-header"
            >
              <div class="header-contents">
                {{i18n "admin.discourse_activity_pub.actor.table.actions"}}
              </div>
            </div>
          </:header>
          <:body>
            {{#each @controller.actors as |actor|}}
              <ActivityPubActorAdminRow
                @actor={{actor}}
                @removeActor={{@controller.removeActor}}
              />
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
