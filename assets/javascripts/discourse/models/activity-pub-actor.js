import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const ActivityPubActor = EmberObject.extend({});

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
