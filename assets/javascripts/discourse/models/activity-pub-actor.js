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
export const actorModels = ["category"];
export const actorAdminPath = "/admin/plugins/ap/actor";
export const actorClientPath = "/ap/local/actor";

const ActivityPubActor = EmberObject.extend({
  isNew: equal("id", newActor.id),

  disable() {
    if (this.isNew) {
      return;
    }
    return ajax(`${actorAdminPath}/${this.id}/disable`, {
      type: "POST",
    }).catch(popupAjaxError);
  },

  enable() {
    if (this.isNew) {
      return;
    }
    return ajax(`${actorAdminPath}/${this.id}/enable`, {
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
    let path = actorAdminPath;
    if (this.id !== "new") {
      path = `${path}/${this.id}`;
      type = "PUT";
    }

    return ajax(path, { type, data }).catch(popupAjaxError);
  },
});

ActivityPubActor.reopenClass({
  find(actorId) {
    return ajax({
      url: `${actorClientPath}/${actorId}`,
      type: "GET",
    })
      .then((response) => response.actor || false)
      .catch(popupAjaxError);
  },

  findByHandle(actorId, handle) {
    return ajax({
      url: `${actorClientPath}/${actorId}/find-by-handle`,
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
      url: `${actorClientPath}/${actorId}/follow`,
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
      url: `${actorClientPath}/${actorId}/follow`,
      type: "DELETE",
      data: {
        target_actor_id: targetActorId,
      },
    })
      .then((response) => !!response?.success)
      .catch(popupAjaxError);
  },

  list(actorId, params, listType) {
    const queryParams = new URLSearchParams();

    if (params.order) {
      queryParams.set("order", params.order);
    }

    if (params.asc) {
      queryParams.set("asc", params.asc);
    }

    const path = `${actorClientPath}/${actorId}/${listType}`;

    let url = `${path}.json`;
    if (queryParams.size) {
      url += `?${queryParams.toString()}`;
    }

    return ajax(url).catch(popupAjaxError);
  },
});

export default ActivityPubActor;
