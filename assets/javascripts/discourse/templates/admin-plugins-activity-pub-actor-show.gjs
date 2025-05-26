import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import { and, eq, not } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ActivityPubActorModel from "../components/activity-pub-actor-model";
import ActivityPubActorStatus from "../components/activity-pub-actor-status";
import ActivityPubCategoryChooser from "../components/activity-pub-category-chooser";
import ActivityPubHandle from "../components/activity-pub-handle";
import ActivityPubPostObjectTypeDropdown from "../components/activity-pub-post-object-type-dropdown";
import ActivityPubPublicationTypeDropdown from "../components/activity-pub-publication-type-dropdown";
import ActivityPubSiteSettingNotice from "../components/activity-pub-site-setting-notice";
import ActivityPubTagChooser from "../components/activity-pub-tag-chooser";
import ActivityPubVisibilityDropdown from "../components/activity-pub-visibility-dropdown";

export default RouteTemplate(
  <template>
    <div class={{@controller.containerClass}}>
      <div class="admin-title activity-pub-actor-title">
        <h2>{{@controller.titleLabel}}</h2>
      </div>

      <div class="activity-pub-actor-header">
        {{#if @controller.actor.isNew}}
          <div class="activity-pub-actor-setting activity-pub-new-actor-model">
            {{#if (eq @controller.actor.model_type "category")}}
              <ActivityPubCategoryChooser
                @value={{@controller.categoryId}}
                @onChange={{@controller.changeCategoryId}}
                @options={{hash hasActor=false}}
              />
            {{/if}}
            {{#if (eq @controller.actor.model_type "tag")}}
              <ActivityPubTagChooser
                @tags={{@controller.tags}}
                @onChange={{@controller.changeTag}}
              />
            {{/if}}
          </div>
        {{else}}
          <ActivityPubActorModel @actor={{@controller.actor}} />
          <ActivityPubActorStatus
            @model={{@controller.actor.model}}
            @modelType={{@controller.actor.model_type}}
          />
          <ActivityPubHandle @actor={{@controller.actor}} />
          <div class="activity-pub-actor-enabled-toggle">
            <DToggleSwitch
              @state={{@controller.enabled}}
              @label={{@controller.enabledLabel}}
              {{on "click" @controller.toggleEnabled}}
            />
          </div>
        {{/if}}
      </div>

      <div class="activity-pub-actor-form-container">
        <div class="activity-pub-actor-form">
          {{#if @controller.showForm}}
            <section class="activity-pub-actor-setting activity-pub-username">
              <label for="activity-pub-username">
                {{i18n "admin.discourse_activity_pub.actor.username"}}
              </label>
              <div class="activity-pub-username-input">
                <Input
                  id="activity-pub-username"
                  @value={{@controller.actor.username}}
                />
                <span
                  class="activity-pub-host"
                >@{{@controller.site.activity_pub_host}}</span>
              </div>
              <div class="activity-pub-actor-setting-description">
                <span>
                  {{i18n
                    "admin.discourse_activity_pub.actor.username_description"
                    min_length=@controller.siteSettings.min_username_length
                    max_length=@controller.siteSettings.max_username_length
                  }}
                </span>
              </div>
            </section>

            <section class="activity-pub-actor-setting activity-pub-name">
              <label for="activity-pub-name">
                {{i18n "admin.discourse_activity_pub.actor.name"}}
              </label>
              <Input id="activity-pub-name" @value={{@controller.actor.name}} />
              <div class="activity-pub-actor-setting-description">
                {{i18n "admin.discourse_activity_pub.actor.name_description"}}
              </div>
            </section>

            {{#if @controller.site.activity_pub_publishing_enabled}}
              <section
                class="activity-pub-actor-setting activity-pub-default-visibility"
              >
                <label for="activity-pub-default-visibility">
                  {{i18n
                    "admin.discourse_activity_pub.actor.default_visibility"
                  }}
                </label>
                <ActivityPubVisibilityDropdown
                  @value={{@controller.actor.default_visibility}}
                  @onChange={{fn (mut @controller.actor.default_visibility)}}
                  @publicationType={{@controller.actor.publication_type}}
                  @objectType={{@controller.actor.post_object_type}}
                />
                <div class="activity-pub-actor-setting-description">
                  {{i18n
                    "admin.discourse_activity_pub.actor.default_visibility_description"
                  }}
                </div>
              </section>

              <section
                class="activity-pub-actor-setting activity-pub-post-object-type"
              >
                <label for="activity-pub-post-object-type">
                  {{i18n "admin.discourse_activity_pub.actor.post_object_type"}}
                </label>
                <ActivityPubPostObjectTypeDropdown
                  @value={{@controller.actor.post_object_type}}
                  @onChange={{fn (mut @controller.actor.post_object_type)}}
                />
                <div class="activity-pub-actor-setting-description">
                  {{i18n
                    "admin.discourse_activity_pub.actor.post_object_type_description"
                  }}
                </div>
              </section>

              <section
                class="activity-pub-actor-setting activity-pub-publication-type"
              >
                <label for="activity-pub-post-object-type">
                  {{i18n "admin.discourse_activity_pub.actor.publication_type"}}
                </label>
                <ActivityPubPublicationTypeDropdown
                  @value={{@controller.actor.publication_type}}
                  @modelType={{@controller.actor.model_type}}
                  @onChange={{fn (mut @controller.actor.publication_type)}}
                />
                <div class="activity-pub-actor-setting-description">
                  {{i18n
                    "admin.discourse_activity_pub.actor.publication_type_description"
                  }}
                </div>
              </section>
            {{/if}}
          {{/if}}
        </div>

        <div class="activity-pub-actor-form-extra">
          {{#if
            (and @controller.showForm @controller.siteSettings.login_required)
          }}
            <section
              class="activity-pub-actor-setting-extra activity-pub-site-settings"
            >
              <div class="activity-pub-site-setting-title">
                {{i18n "admin.discourse_activity_pub.actor.site_setting.title"}}
              </div>
              <ActivityPubSiteSettingNotice
                @setting="activity_pub_enabled"
                @modelType={{@controller.actor.model_type}}
              />
              <ActivityPubSiteSettingNotice
                @setting="login_required"
                @modelType={{@controller.actor.model_type}}
              />
            </section>
          {{/if}}
        </div>
      </div>

      <div class="activity-pub-actor-gutter">
        {{#if @controller.showForm}}
          <ConditionalLoadingSpinner
            @condition={{@controller.saving}}
            @size="small"
          />
          {{#if @controller.saveResponse}}
            <span
              class="activity-pub-actor-save-response
                {{@controller.saveResponse}}"
            >
              {{#if @controller.saveSuccess}}
                {{icon "check"}}
                {{i18n "admin.discourse_activity_pub.actor.save.success"}}
              {{else}}
                {{icon "xmark"}}
                {{i18n "admin.discourse_activity_pub.actor.save.failed"}}
              {{/if}}
            </span>
          {{/if}}
          <DButton
            @action={{@controller.saveActor}}
            @label="admin.discourse_activity_pub.actor.save.label"
            @title="admin.discourse_activity_pub.actor.save.title"
            @disabled={{not @controller.canSave}}
            class="activity-pub-save-actor btn-primary"
          />
        {{/if}}
      </div>
    </div>
  </template>
);
