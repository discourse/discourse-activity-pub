import Component from "@glimmer/component";
import ActivityPubAttribute from "./activity-pub-attribute";

export default class ActivityPubAttributes extends Component {
  get topic() {
    return this.args.topic;
  }

  get post() {
    return this.args.post;
  }

  get postActor() {
    return this.post.topic.getActivityPubPostActor(this.post.id);
  }

  <template>
    <div class="activity-pub-attributes">
      {{#if this.topic}}
        <ActivityPubAttribute
          @attribute="object_type"
          @value={{this.topic.activity_pub_object_type}}
          @uri={{this.topic.activity_pub_object_id}}
        />
      {{/if}}
      <ActivityPubAttribute
        @attribute="object_type"
        @value={{this.post.activity_pub_object_type}}
        @uri={{this.post.activity_pub_object_id}}
      />
      <ActivityPubAttribute
        @attribute="visibility"
        @value={{this.post.activity_pub_visibility}}
      />
      {{#if this.postActor}}
        <ActivityPubAttribute
          @attribute="actor"
          @value={{this.postActor.actor.handle}}
          @uri={{this.postActor.actor.ap_id}}
        />
      {{/if}}
    </div>
  </template>
}
