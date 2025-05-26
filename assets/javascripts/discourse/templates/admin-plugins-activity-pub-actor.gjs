import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import ResponsiveTable from "discourse/components/responsive-table";
import TableHeaderToggle from "discourse/components/table-header-toggle";
import { i18n } from "discourse-i18n";
import ActivityPubActor from "../components/activity-pub-actor";
import ActivityPubActorModel from "../components/activity-pub-actor-model";

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
              class="activity-pub-actor-table-actions directory-table__column-header"
            >
              <div class="header-contents">
                {{i18n "admin.discourse_activity_pub.actor.table.actions"}}
              </div>
            </div>
          </:header>
          <:body>
            {{#each @controller.actors as |actor|}}
              <div class="directory-table__row activity-pub-actor-table-row">
                <div
                  class="directory-table__cell activity-pub-actor-table-actor"
                >
                  <ActivityPubActor @actor={{actor}} />
                </div>
                <div
                  class="directory-table__cell activity-pub-actor-table-model"
                >
                  <ActivityPubActorModel @actor={{actor}} />
                </div>
                <div
                  class="directory-table__cell activity-pub-actor-table-actions"
                >
                  <DButton
                    @action={{fn @controller.editActor actor}}
                    @label="admin.discourse_activity_pub.actor.edit.label"
                    @title="admin.discourse_activity_pub.actor.edit.title"
                    @icon="pencil"
                    class="activity-pub-actor-edit-btn"
                  />
                </div>
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
