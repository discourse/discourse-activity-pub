import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import ResponsiveTable from "discourse/components/responsive-table";
import TableHeaderToggle from "discourse/components/table-header-toggle";
import formatDate from "discourse/helpers/format-date";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="admin-title activity-pub-log-title">
      <h2>{{i18n "admin.discourse_activity_pub.log.title"}}</h2>
    </div>

    <LoadMore
      @selector=".directory-table .directory-table__cell"
      @action={{@controller.loadMore}}
      class="activity-pub-logs-container"
    >
      {{#if @controller.hasLogs}}
        <ResponsiveTable @className="activity-pub-log-table">
          <:header>
            <TableHeaderToggle
              @onToggle={{@controller.updateOrder}}
              @field="created_at"
              @labelKey="admin.discourse_activity_pub.log.created_at"
              @automatic={{true}}
              @order={{@controller.order}}
              @asc={{@controller.asc}}
            />
            <TableHeaderToggle
              @onToggle={{@controller.updateOrder}}
              @field="level"
              @labelKey="admin.discourse_activity_pub.log.level"
              @automatic={{true}}
              @order={{@controller.order}}
              @asc={{@controller.asc}}
            />
            <TableHeaderToggle
              @field="message"
              @labelKey="admin.discourse_activity_pub.log.message"
              @automatic={{true}}
              @order={{@controller.order}}
              @asc={{@controller.asc}}
            />
            <div
              class="activity-pub-json-table-json directory-table__column-header"
            >
              <div class="header-contents">
                {{i18n "admin.discourse_activity_pub.log.json.label"}}
              </div>
            </div>
          </:header>
          <:body>
            {{#each @controller.logs as |logEntry|}}
              <div class="directory-table__row activity-pub-log-row">
                <div class="directory-table__cell activity-pub-log-created-at">
                  {{formatDate logEntry.created_at leaveAgo="true"}}
                </div>
                <div class="directory-table__cell activity-pub-log-level">
                  {{logEntry.level}}
                </div>
                <div class="directory-table__cell activity-pub-log-message">
                  {{logEntry.message}}
                </div>
                <div class="directory-table__cell activity-pub-log-json">
                  {{#if logEntry.json}}
                    <DButton
                      @action={{fn @controller.showJson logEntry}}
                      @icon="code"
                      @label="admin.discourse_activity_pub.log.json.show.label"
                      @title="admin.discourse_activity_pub.log.json.show.title"
                      class="btn-default activity-pub-log-show-json-btn"
                    />
                  {{/if}}
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
