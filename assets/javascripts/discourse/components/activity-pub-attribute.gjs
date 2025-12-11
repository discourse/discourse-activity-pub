import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import dIcon from "discourse/helpers/d-icon";
import { camelCaseToSnakeCase } from "discourse/lib/case-converter";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const icons = {
  note: "file",
  article: "file",
  collection: "folder",
  orderedcollection: "folder",
  public: "globe",
  private: "lock",
  actor: "user",
  topicActor: "user-group",
};

export default class ActivityPubAttribute extends Component {
  @service toasts;

  @action
  async copyURI() {
    if (!this.args.uri) {
      return;
    }
    await clipboardCopy(this.args.uri);
    this.toasts.success({
      duration: "short",
      data: {
        message: i18n("discourse_activity_pub.copy_uri.copied"),
      },
    });
  }

  get actor() {
    return (
      this.args.attribute === "actor" || this.args.attribute === "topicActor"
    );
  }

  get icon() {
    let key = this.args.value?.toLowerCase() || "note";
    if (this.actor) {
      key = this.args.attribute;
    }
    return icons[key];
  }

  get label() {
    if (!this.args.value) {
      return "";
    }
    if (this.actor) {
      return this.args.value;
    } else {
      return i18n(
        `discourse_activity_pub.${
          this.args.attribute
        }.label.${camelCaseToSnakeCase(this.args.value)}`
      );
    }
  }

  get classes() {
    let classes = `activity-pub-attribute ${dasherize(this.args.attribute)}`;
    if (!this.actor && this.args.value) {
      classes += ` ${dasherize(this.args.value)}`;
    }
    if (this.args.uri) {
      classes += " copiable";
    }
    return classes;
  }

  <template>
    <div class={{this.classes}} {{on "click" this.copyURI}} role="button">
      {{dIcon this.icon}}
      {{this.label}}
    </div>
  </template>
}
