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
      duration: 2500,
      data: {
        message: i18n("discourse_activity_pub.copy_uri.copied"),
      },
    });
  }

  get icon() {
    let key = this.args.value?.toLowerCase() || "note";
    if (this.args.attribute === "actor") {
      key = "actor";
    }
    return icons[key];
  }

  get label() {
    if (!this.args.value) {
      return "";
    }
    if (this.args.attribute === "actor") {
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
    let classes = `activity-pub-attribute ${dasherize(
      this.args.attribute
    )} ${this.args.value?.toLowerCase()}`;
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
