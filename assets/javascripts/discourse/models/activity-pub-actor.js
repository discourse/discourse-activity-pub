import EmberObject from "@ember/object";
import { equal } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export const newActor = {
  id: "new",
  default_visibility: "public",
  post_object_type: "Note",
  publication_type: "first_post",
};

const ActivityPubActor = EmberObject.extend({
  isNew: equal("id", newActor.id),

  disable() {
    if (this.isNew) {
      return;
    }
    return ajax(`/admin/plugins/ap/actor/${this.id}/disable`, {
      type: "POST",
    }).catch(popupAjaxError);
  },

  enable() {
    if (this.isNew) {
      return;
    }
    return ajax(`/admin/plugins/ap/actor/${this.id}/enable`, {
      type: "POST",
    }).catch(popupAjaxError);
  },

  save() {
    let data = {
      actor: {
        enabled: this.enabled,
        model_id: this.model_id,
        model_type: this.model_type,
        username: this.username,
        name: this.name,
        default_visibility: this.default_visibility,
        publication_type: this.publication_type,
        post_object_type: this.post_object_type,
      },
    };
    let type = "POST";
    let path = "/admin/plugins/ap/actor";

    if (this.id !== "new") {
      path = `${path}/${this.id}`;
      type = "PUT";
    }

    return ajax(path, { type, data }).catch(popupAjaxError);
  },
});

ActivityPubActor.reopenClass({
  findByHandle(actorId, handle) {
    return ajax({
      url: `/ap/actor/${actorId}/find-by-handle`,
      type: "GET",
      data: {
        handle,
      },
    })
      .then((response) => response.actor || false)
      .catch(popupAjaxError);
  },

  follow(actorId, targetActorId) {
    return ajax({
      url: `/ap/actor/${actorId}/follow`,
      type: "POST",
      data: {
        target_actor_id: targetActorId,
      },
    })
      .then((response) => !!response?.success)
      .catch(popupAjaxError);
  },

  unfollow(actorId, targetActorId) {
    return ajax({
      url: `/ap/actor/${actorId}/follow`,
      type: "DELETE",
      data: {
        target_actor_id: targetActorId,
      },
    })
      .then((response) => !!response?.success)
      .catch(popupAjaxError);
  },
});

export default ActivityPubActor;
